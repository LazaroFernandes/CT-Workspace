
create schema if not exists private authorization postgres;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;
grant usage on schema private to authenticated;

alter default privileges for role postgres in schema private
  revoke execute on functions from public;

alter function public.is_active_user() set schema private;
alter function public.current_user_role() set schema private;
alter function public.is_admin() set schema private;
alter function public.can_manage_projects() set schema private;
alter function public.can_access_project(uuid) set schema private;
alter function public.can_update_checklist(uuid) set schema private;

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.ativo
  );
$$;

create or replace function private.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.ativo;
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.current_user_role() = 'ADMIN', false);
$$;

create or replace function private.can_manage_projects()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.current_user_role() in ('ADMIN', 'GESTOR'), false);
$$;

create or replace function private.can_access_project(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user()
    and (
      private.can_manage_projects()
      or exists (
        select 1
        from public.projects p
        where p.id = target_project_id
          and (
            p.created_by = auth.uid()
            or p.responsavel_principal_id = auth.uid()
          )
      )
      or exists (
        select 1
        from public.project_members pm
        where pm.project_id = target_project_id
          and pm.user_id = auth.uid()
          and pm.archived_at is null
      )
    );
$$;

create or replace function private.can_update_checklist(target_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.can_manage_projects()
    or exists (
      select 1
      from public.checklist_items c
      join public.project_stages s on s.id = c.stage_id
      where c.id = target_item_id
        and c.responsavel_id = auth.uid()
        and c.archived_at is null
        and s.archived_at is null
        and private.can_access_project(s.project_id)
    );
$$;

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and not private.is_admin()
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

create or replace function public.protect_member_checklist_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not private.can_manage_projects() then
    if old.responsavel_id is distinct from auth.uid() then
      raise exception 'O item não está atribuído ao usuário atual.';
    end if;

    if new.stage_id is distinct from old.stage_id
       or new.titulo is distinct from old.titulo
       or new.descricao is distinct from old.descricao
       or new.responsavel_id is distinct from old.responsavel_id
       or new.due_date is distinct from old.due_date
       or new.ordem is distinct from old.ordem
       or new.archived_at is distinct from old.archived_at then
      raise exception 'Membros podem alterar apenas a conclusão de itens atribuídos.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.is_active_user() from public, anon, authenticated;
revoke all on function private.current_user_role() from public, anon, authenticated;
revoke all on function private.is_admin() from public, anon, authenticated;
revoke all on function private.can_manage_projects() from public, anon, authenticated;
revoke all on function private.can_access_project(uuid) from public, anon, authenticated;
revoke all on function private.can_update_checklist(uuid) from public, anon, authenticated;

grant execute on function private.is_active_user() to authenticated;
grant execute on function private.current_user_role() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.can_manage_projects() to authenticated;
grant execute on function private.can_access_project(uuid) to authenticated;
grant execute on function private.can_update_checklist(uuid) to authenticated;
