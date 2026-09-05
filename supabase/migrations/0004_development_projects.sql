create type public.development_project_status as enum (
  'PLANEJAMENTO',
  'ATIVO',
  'PAUSADO',
  'CONCLUIDO',
  'ARQUIVADO'
);

create type public.development_environment as enum (
  'LOCAL',
  'DESENVOLVIMENTO',
  'STAGING',
  'PRODUCAO'
);

create table public.development_projects (
  id uuid primary key default extensions.gen_random_uuid(),
  titulo text not null check (char_length(btrim(titulo)) between 3 and 180),
  descricao text,
  project_id uuid references public.projects (id) on delete restrict,
  repository_url text check (
    repository_url is null
    or (
      char_length(repository_url) <= 500
      and repository_url ~ '^https?://'
    )
  ),
  repository_provider text check (
    repository_provider is null
    or repository_provider ~ '^[A-Z][A-Z0-9_]{1,39}$'
  ),
  repository_owner text check (
    repository_owner is null
    or char_length(btrim(repository_owner)) between 1 and 120
  ),
  repository_name text check (
    repository_name is null
    or char_length(btrim(repository_name)) between 1 and 180
  ),
  default_branch text check (
    default_branch is null
    or char_length(btrim(default_branch)) between 1 and 255
  ),
  status public.development_project_status not null default 'PLANEJAMENTO',
  ambiente public.development_environment not null default 'LOCAL',
  ultima_atividade timestamptz,
  ultimo_commit_sha text check (
    ultimo_commit_sha is null
    or ultimo_commit_sha ~ '^[0-9A-Fa-f]{7,64}$'
  ),
  ultimo_commit_titulo text check (
    ultimo_commit_titulo is null
    or char_length(btrim(ultimo_commit_titulo)) between 1 and 500
  ),
  ultimo_commit_autor text check (
    ultimo_commit_autor is null
    or char_length(btrim(ultimo_commit_autor)) between 1 and 180
  ),
  ultimo_commit_data timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  archived_at timestamptz
);

create index development_projects_project_idx
  on public.development_projects (project_id)
  where archived_at is null;
create index development_projects_status_environment_idx
  on public.development_projects (status, ambiente)
  where archived_at is null;
create index development_projects_last_activity_idx
  on public.development_projects (ultima_atividade desc)
  where archived_at is null;
create index development_projects_created_by_idx
  on public.development_projects (created_by)
  where archived_at is null;

create trigger development_projects_set_updated_at
before update on public.development_projects
for each row execute function public.set_updated_at();

alter table public.development_projects enable row level security;

create policy "development_projects_select"
on public.development_projects for select
to authenticated
using (
  public.can_manage_projects()
  or (
    project_id is not null
    and public.can_access_project(project_id)
  )
);

create policy "development_projects_insert"
on public.development_projects for insert
to authenticated
with check (
  public.can_manage_projects()
  and created_by = auth.uid()
);

create policy "development_projects_update"
on public.development_projects for update
to authenticated
using (public.can_manage_projects())
with check (public.can_manage_projects());

revoke all on public.development_projects from anon, authenticated;
grant select, insert, update on public.development_projects to authenticated;
