create or replace function public.is_active_user()
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

create or replace function public.current_user_role()
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

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.current_user_role() = 'ADMIN', false);
$$;

create or replace function public.can_manage_projects()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.current_user_role() in ('ADMIN', 'GESTOR'), false);
$$;

create or replace function public.can_access_project(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
    and (
      public.can_manage_projects()
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

create or replace function public.can_update_checklist(target_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.can_manage_projects()
    or exists (
      select 1
      from public.checklist_items c
      join public.project_stages s on s.id = c.stage_id
      where c.id = target_item_id
        and c.responsavel_id = auth.uid()
        and c.archived_at is null
        and s.archived_at is null
        and public.can_access_project(s.project_id)
    );
$$;

create or replace function public.protect_member_checklist_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not public.can_manage_projects() then
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

create trigger checklist_protect_member_update
before update on public.checklist_items
for each row execute function public.protect_member_checklist_update();

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.units enable row level security;
alter table public.areas enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_stages enable row level security;
alter table public.checklist_items enable row level security;
alter table public.project_commits enable row level security;
alter table public.project_history enable row level security;
alter table public.project_comments enable row level security;
alter table public.related_conversations enable row level security;
alter table public.related_links enable row level security;
alter table public.inbox_items enable row level security;

create policy "profiles_select"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin()
  or (public.is_active_user() and ativo)
);

create policy "profiles_update"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

create policy "companies_select"
on public.companies for select
to authenticated
using (public.is_active_user());
create policy "companies_insert"
on public.companies for insert
to authenticated
with check (public.is_admin());
create policy "companies_update"
on public.companies for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "units_select"
on public.units for select
to authenticated
using (public.is_active_user());
create policy "units_insert"
on public.units for insert
to authenticated
with check (public.is_admin());
create policy "units_update"
on public.units for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "areas_select"
on public.areas for select
to authenticated
using (public.is_active_user());
create policy "areas_insert"
on public.areas for insert
to authenticated
with check (public.is_admin());
create policy "areas_update"
on public.areas for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "projects_select"
on public.projects for select
to authenticated
using (public.can_access_project(id));
create policy "projects_insert"
on public.projects for insert
to authenticated
with check (public.can_manage_projects() and created_by = auth.uid());
create policy "projects_update"
on public.projects for update
to authenticated
using (public.can_manage_projects())
with check (public.can_manage_projects());

create policy "project_members_select"
on public.project_members for select
to authenticated
using (public.can_access_project(project_id));
create policy "project_members_insert"
on public.project_members for insert
to authenticated
with check (public.can_manage_projects() and created_by = auth.uid());
create policy "project_members_update"
on public.project_members for update
to authenticated
using (public.can_manage_projects())
with check (public.can_manage_projects());

create policy "stages_select"
on public.project_stages for select
to authenticated
using (public.can_access_project(project_id));
create policy "stages_insert"
on public.project_stages for insert
to authenticated
with check (public.can_manage_projects() and public.can_access_project(project_id));
create policy "stages_update"
on public.project_stages for update
to authenticated
using (public.can_manage_projects() and public.can_access_project(project_id))
with check (public.can_manage_projects() and public.can_access_project(project_id));

create policy "checklist_select"
on public.checklist_items for select
to authenticated
using (
  exists (
    select 1
    from public.project_stages s
    where s.id = stage_id
      and public.can_access_project(s.project_id)
  )
);
create policy "checklist_insert"
on public.checklist_items for insert
to authenticated
with check (
  public.can_manage_projects()
  and exists (
    select 1
    from public.project_stages s
    where s.id = stage_id
      and public.can_access_project(s.project_id)
  )
);
create policy "checklist_update"
on public.checklist_items for update
to authenticated
using (public.can_update_checklist(id))
with check (public.can_update_checklist(id));

create policy "commits_select"
on public.project_commits for select
to authenticated
using (public.can_access_project(project_id));
create policy "commits_insert_manual"
on public.project_commits for insert
to authenticated
with check (
  public.can_access_project(project_id)
  and user_id = auth.uid()
  and origem = 'MANUAL'
);

create policy "history_select"
on public.project_history for select
to authenticated
using (public.can_access_project(project_id));

create policy "comments_select"
on public.project_comments for select
to authenticated
using (public.can_access_project(project_id));
create policy "comments_insert"
on public.project_comments for insert
to authenticated
with check (public.can_access_project(project_id) and user_id = auth.uid());
create policy "comments_update"
on public.project_comments for update
to authenticated
using (public.can_manage_projects() or user_id = auth.uid())
with check (public.can_access_project(project_id) and (public.can_manage_projects() or user_id = auth.uid()));

create policy "conversations_select"
on public.related_conversations for select
to authenticated
using (public.can_access_project(project_id));
create policy "conversations_insert"
on public.related_conversations for insert
to authenticated
with check (public.can_manage_projects() and created_by = auth.uid());
create policy "conversations_update"
on public.related_conversations for update
to authenticated
using (public.can_manage_projects() and public.can_access_project(project_id))
with check (public.can_manage_projects() and public.can_access_project(project_id));

create policy "links_select"
on public.related_links for select
to authenticated
using (public.can_access_project(project_id));
create policy "links_insert"
on public.related_links for insert
to authenticated
with check (public.can_manage_projects() and created_by = auth.uid());
create policy "links_update"
on public.related_links for update
to authenticated
using (public.can_manage_projects() and public.can_access_project(project_id))
with check (public.can_manage_projects() and public.can_access_project(project_id));

create policy "inbox_select"
on public.inbox_items for select
to authenticated
using (public.can_manage_projects());
create policy "inbox_insert"
on public.inbox_items for insert
to authenticated
with check (public.can_manage_projects() and created_by = auth.uid());
create policy "inbox_update"
on public.inbox_items for update
to authenticated
using (public.can_manage_projects())
with check (public.can_manage_projects());

revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.companies to authenticated;
grant select, insert, update on public.units to authenticated;
grant select, insert, update on public.areas to authenticated;
grant select, insert, update on public.projects to authenticated;
grant select, insert, update on public.project_members to authenticated;
grant select, insert, update on public.project_stages to authenticated;
grant select, insert, update on public.checklist_items to authenticated;
grant select, insert on public.project_commits to authenticated;
grant select on public.project_history to authenticated;
grant select, insert, update on public.project_comments to authenticated;
grant select, insert, update on public.related_conversations to authenticated;
grant select, insert, update on public.related_links to authenticated;
grant select, insert, update on public.inbox_items to authenticated;

revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.can_manage_projects() to authenticated;
grant execute on function public.can_access_project(uuid) to authenticated;
grant execute on function public.can_update_checklist(uuid) to authenticated;
