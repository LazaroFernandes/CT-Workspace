create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
begin
  display_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'nome'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(coalesce(new.email, 'Novo usuário'), '@', 1)
  );

  insert into public.profiles (id, nome, email)
  values (new.id, display_name, coalesce(new.email, new.id::text || '@sem-email.local'))
  on conflict (id) do nothing;

  return new;
end;
$$;

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and not public.is_admin()
     and (
       new.role is distinct from old.role
       or new.ativo is distinct from old.ativo
       or new.email is distinct from old.email
       or new.id is distinct from old.id
     ) then
    raise exception 'Somente administradores podem alterar papel, ativação ou identidade do perfil.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_project_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  scoped_unit_id uuid;
begin
  select a.unit_id
  into scoped_unit_id
  from public.areas a
  where a.id = new.area_id;

  if scoped_unit_id is not null and scoped_unit_id <> new.unit_id then
    raise exception 'A área selecionada não pertence à unidade do projeto.';
  end if;

  return new;
end;
$$;

create or replace function public.sync_project_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'CONCLUIDO' then
    new.data_conclusao = coalesce(new.data_conclusao, current_date);
    new.progresso = 100;
  elsif tg_op = 'UPDATE' then
    if old.status = 'CONCLUIDO' then
      new.data_conclusao = null;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.sync_stage_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'CONCLUIDA' then
    if tg_op = 'INSERT' then
      new.data_conclusao = coalesce(new.data_conclusao, current_date);
    elsif old.status <> 'CONCLUIDA' then
      new.data_conclusao = coalesce(new.data_conclusao, current_date);
    end if;
  elsif new.status <> 'CONCLUIDA' then
    new.data_conclusao = null;
  end if;

  return new;
end;
$$;

create or replace function public.sync_checklist_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_completed then
    if tg_op = 'INSERT' then
      new.completed_at = coalesce(new.completed_at, now());
      new.completed_by = coalesce(new.completed_by, auth.uid());
    elsif not old.is_completed then
      new.completed_at = coalesce(new.completed_at, now());
      new.completed_by = coalesce(new.completed_by, auth.uid());
    end if;
  else
    new.completed_at = null;
    new.completed_by = null;
  end if;

  return new;
end;
$$;

create or replace function public.log_project_event(
  target_project_id uuid,
  action_name text,
  event_title text,
  event_description text,
  event_type public.commit_type,
  entity_type text,
  entity_id uuid,
  field_name text default null,
  old_value jsonb default null,
  new_value jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.project_history (
    project_id,
    user_id,
    acao,
    entidade_tipo,
    entidade_id,
    campo,
    valor_anterior,
    valor_novo,
    metadata
  ) values (
    target_project_id,
    auth.uid(),
    action_name,
    entity_type,
    entity_id,
    field_name,
    old_value,
    new_value,
    jsonb_build_object('origem', 'SISTEMA')
  );

  if event_title is not null then
    insert into public.project_commits (
      project_id,
      user_id,
      titulo,
      descricao,
      tipo,
      origem,
      metadata
    ) values (
      target_project_id,
      auth.uid(),
      event_title,
      event_description,
      event_type,
      'SISTEMA',
      jsonb_build_object('acao', action_name, 'entidade_tipo', entity_type, 'entidade_id', entity_id)
    );
  end if;
end;
$$;

create or replace function public.audit_project_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_project_event(
      new.id,
      'PROJETO_CRIADO',
      'Projeto criado',
      new.titulo,
      'ATUALIZACAO',
      'project',
      new.id,
      null,
      null,
      to_jsonb(new)
    );
    return new;
  end if;

  if new.status is distinct from old.status then
    perform public.log_project_event(
      new.id,
      case
        when new.status = 'CONCLUIDO' then 'PROJETO_CONCLUIDO'
        when old.status = 'CONCLUIDO' then 'PROJETO_REABERTO'
        else 'STATUS_ALTERADO'
      end,
      case
        when new.status = 'CONCLUIDO' then 'Projeto concluído'
        when old.status = 'CONCLUIDO' then 'Projeto reaberto'
        else 'Status alterado'
      end,
      old.status::text || ' → ' || new.status::text,
      case when new.status = 'CONCLUIDO' then 'CONCLUSAO'::public.commit_type else 'STATUS'::public.commit_type end,
      'project',
      new.id,
      'status',
      to_jsonb(old.status),
      to_jsonb(new.status)
    );
  end if;

  if new.prioridade is distinct from old.prioridade then
    perform public.log_project_event(
      new.id, 'PRIORIDADE_ALTERADA', 'Prioridade alterada',
      old.prioridade::text || ' → ' || new.prioridade::text,
      'ATUALIZACAO', 'project', new.id, 'prioridade',
      to_jsonb(old.prioridade), to_jsonb(new.prioridade)
    );
  end if;

  if new.responsavel_principal_id is distinct from old.responsavel_principal_id then
    perform public.log_project_event(
      new.id, 'RESPONSAVEL_ALTERADO', 'Responsável principal alterado', null,
      'ATUALIZACAO', 'project', new.id, 'responsavel_principal_id',
      to_jsonb(old.responsavel_principal_id), to_jsonb(new.responsavel_principal_id)
    );
  end if;

  if new.proxima_acao is distinct from old.proxima_acao then
    perform public.log_project_event(
      new.id, 'PROXIMA_ACAO_ALTERADA', 'Próxima ação atualizada', new.proxima_acao,
      'ATUALIZACAO', 'project', new.id, 'proxima_acao',
      to_jsonb(old.proxima_acao), to_jsonb(new.proxima_acao)
    );
  end if;

  return new;
end;
$$;

create or replace function public.audit_stage_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_project_event(
      new.project_id, 'ETAPA_CRIADA', null, null,
      'ATUALIZACAO', 'stage', new.id, null, null, to_jsonb(new)
    );
  elsif new.status is distinct from old.status and new.status = 'CONCLUIDA' then
    perform public.log_project_event(
      new.project_id, 'ETAPA_CONCLUIDA', 'Etapa concluída', new.titulo,
      'ETAPA_CONCLUIDA', 'stage', new.id, 'status',
      to_jsonb(old.status), to_jsonb(new.status)
    );
  elsif new.status is distinct from old.status and old.status = 'CONCLUIDA' then
    perform public.log_project_event(
      new.project_id, 'ETAPA_REABERTA', 'Etapa reaberta', new.titulo,
      'STATUS', 'stage', new.id, 'status',
      to_jsonb(old.status), to_jsonb(new.status)
    );
  end if;

  update public.projects
  set ultima_atualizacao = now()
  where id = new.project_id;

  return new;
end;
$$;

create or replace function public.audit_checklist_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_project_id uuid;
begin
  select s.project_id
  into parent_project_id
  from public.project_stages s
  where s.id = new.stage_id;

  if tg_op = 'UPDATE' and new.is_completed is distinct from old.is_completed then
    perform public.log_project_event(
      parent_project_id,
      case when new.is_completed then 'CHECKLIST_CONCLUIDO' else 'CHECKLIST_REABERTO' end,
      case when new.is_completed then 'Item de checklist concluído' else 'Item de checklist reaberto' end,
      new.titulo,
      'CHECKLIST',
      'checklist_item',
      new.id,
      'is_completed',
      to_jsonb(old.is_completed),
      to_jsonb(new.is_completed)
    );
  end if;

  return new;
end;
$$;

create or replace function public.recalculate_project_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_project_id uuid;
  total_items integer;
  completed_items integer;
begin
  if tg_op = 'DELETE' then
    select s.project_id
    into parent_project_id
    from public.project_stages s
    where s.id = old.stage_id;
  else
    select s.project_id
    into parent_project_id
    from public.project_stages s
    where s.id = new.stage_id;
  end if;

  select count(*), count(*) filter (where c.is_completed)
  into total_items, completed_items
  from public.checklist_items c
  join public.project_stages s on s.id = c.stage_id
  where s.project_id = parent_project_id
    and s.archived_at is null
    and c.archived_at is null;

  update public.projects
  set progresso = case
        when status = 'CONCLUIDO' then 100
        when total_items = 0 then progresso
        else round((completed_items::numeric / total_items::numeric) * 100)::smallint
      end,
      progresso_manual = total_items = 0,
      ultima_atualizacao = now()
  where id = parent_project_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.touch_project_from_child()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    update public.projects
    set ultima_atualizacao = now()
    where id = old.project_id;
    return old;
  end if;

  update public.projects
  set ultima_atualizacao = now()
  where id = new.project_id;
  return new;
end;
$$;

create or replace function public.touch_project_from_commit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.projects
  set ultima_atualizacao = now()
  where id = new.project_id;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger profiles_protect_security before update on public.profiles
for each row execute function public.protect_profile_security_fields();
create trigger companies_set_updated_at before update on public.companies
for each row execute function public.set_updated_at();
create trigger units_set_updated_at before update on public.units
for each row execute function public.set_updated_at();
create trigger areas_set_updated_at before update on public.areas
for each row execute function public.set_updated_at();
create trigger projects_set_updated_at before update on public.projects
for each row execute function public.set_updated_at();
create trigger stages_set_updated_at before update on public.project_stages
for each row execute function public.set_updated_at();
create trigger checklist_set_updated_at before update on public.checklist_items
for each row execute function public.set_updated_at();
create trigger comments_set_updated_at before update on public.project_comments
for each row execute function public.set_updated_at();
create trigger inbox_set_updated_at before update on public.inbox_items
for each row execute function public.set_updated_at();

create trigger projects_validate_scope before insert or update of company_id, unit_id, area_id on public.projects
for each row execute function public.validate_project_scope();
create trigger projects_sync_completion before insert or update of status on public.projects
for each row execute function public.sync_project_completion();
create trigger stages_sync_completion before insert or update of status on public.project_stages
for each row execute function public.sync_stage_completion();
create trigger checklist_sync_completion before insert or update of is_completed on public.checklist_items
for each row execute function public.sync_checklist_completion();

create trigger projects_audit after insert or update on public.projects
for each row execute function public.audit_project_changes();
create trigger stages_audit after insert or update on public.project_stages
for each row execute function public.audit_stage_changes();
create trigger checklist_audit after insert or update on public.checklist_items
for each row execute function public.audit_checklist_changes();
create trigger checklist_recalculate_progress after insert or update or delete on public.checklist_items
for each row execute function public.recalculate_project_progress();
create trigger commits_touch_project after insert on public.project_commits
for each row execute function public.touch_project_from_commit();
create trigger comments_touch_project after insert or update on public.project_comments
for each row execute function public.touch_project_from_child();
create trigger conversations_touch_project after insert or update on public.related_conversations
for each row execute function public.touch_project_from_child();
create trigger links_touch_project after insert or update on public.related_links
for each row execute function public.touch_project_from_child();

revoke all on function public.log_project_event(uuid, text, text, text, public.commit_type, text, uuid, text, jsonb, jsonb) from public;
