create extension if not exists pgcrypto with schema extensions;

create type public.app_role as enum ('ADMIN', 'GESTOR', 'MEMBRO');
create type public.project_status as enum (
  'BACKLOG',
  'EM_PLANEJAMENTO',
  'EM_ANDAMENTO',
  'AGUARDANDO',
  'BLOQUEADO',
  'CONCLUIDO',
  'ARQUIVADO'
);
create type public.project_priority as enum ('BAIXA', 'MEDIA', 'ALTA', 'CRITICA');
create type public.stage_status as enum ('PENDENTE', 'EM_ANDAMENTO', 'CONCLUIDA', 'BLOQUEADA');
create type public.commit_type as enum (
  'ATUALIZACAO',
  'ETAPA_CONCLUIDA',
  'CHECKLIST',
  'STATUS',
  'DECISAO',
  'DOCUMENTO',
  'COMENTARIO',
  'CONCLUSAO'
);
create type public.event_source as enum ('MANUAL', 'SISTEMA', 'INTEGRACAO');
create type public.conversation_origin as enum ('CHATGPT', 'REUNIAO', 'WHATSAPP', 'OUTRO');
create type public.link_type as enum ('DOCUMENTO', 'PLANILHA', 'DRIVE', 'GITHUB', 'CANVA', 'PDF', 'OUTRO');
create type public.inbox_status as enum ('NOVO', 'ANALISANDO', 'CONVERTIDO', 'DESCARTADO');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  email text not null unique,
  avatar_url text,
  cargo text,
  role public.app_role not null default 'MEMBRO',
  ativo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.companies (
  id uuid primary key default extensions.gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  sigla text not null check (sigla ~ '^[A-Z0-9]{2,10}$'),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create unique index companies_name_active_uidx on public.companies (lower(nome)) where archived_at is null;
create unique index companies_code_active_uidx on public.companies (sigla) where archived_at is null;

create table public.units (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  sigla text not null check (sigla ~ '^[A-Z0-9]{2,10}$'),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (id, company_id)
);

create unique index units_name_active_uidx on public.units (company_id, lower(nome)) where archived_at is null;
create unique index units_code_active_uidx on public.units (company_id, sigla) where archived_at is null;

create table public.areas (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  unit_id uuid,
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  sigla text not null check (sigla ~ '^[A-Z0-9]{2,10}$'),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  foreign key (unit_id, company_id) references public.units (id, company_id) on delete restrict,
  unique (id, company_id)
);

create unique index areas_global_name_active_uidx on public.areas (company_id, lower(nome))
  where unit_id is null and archived_at is null;
create unique index areas_unit_name_active_uidx on public.areas (company_id, unit_id, lower(nome))
  where unit_id is not null and archived_at is null;
create index areas_company_unit_idx on public.areas (company_id, unit_id) where archived_at is null;

create table public.projects (
  id uuid primary key default extensions.gen_random_uuid(),
  codigo text not null check (codigo ~ '^[A-Z0-9]+(?:-[A-Z0-9]+){1,5}$'),
  titulo text not null check (char_length(btrim(titulo)) between 3 and 180),
  descricao text,
  company_id uuid not null,
  unit_id uuid not null,
  area_id uuid not null,
  status public.project_status not null default 'BACKLOG',
  prioridade public.project_priority not null default 'MEDIA',
  responsavel_principal_id uuid references public.profiles (id) on delete restrict,
  data_inicio date not null default current_date,
  data_prevista date,
  data_conclusao date,
  progresso smallint not null default 0 check (progresso between 0 and 100),
  progresso_manual boolean not null default true,
  proxima_acao text,
  ultima_atualizacao timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  archived_at timestamptz,
  foreign key (unit_id, company_id) references public.units (id, company_id) on delete restrict,
  foreign key (area_id, company_id) references public.areas (id, company_id) on delete restrict,
  constraint projects_completion_state_check check (
    (status = 'CONCLUIDO' and data_conclusao is not null)
    or (status <> 'CONCLUIDO')
  ),
  constraint projects_due_after_start_check check (data_prevista is null or data_prevista >= data_inicio)
);

create unique index projects_code_active_uidx on public.projects (codigo) where archived_at is null;
create index projects_company_idx on public.projects (company_id) where archived_at is null;
create index projects_unit_idx on public.projects (unit_id) where archived_at is null;
create index projects_area_idx on public.projects (area_id) where archived_at is null;
create index projects_status_priority_idx on public.projects (status, prioridade) where archived_at is null;
create index projects_responsible_idx on public.projects (responsavel_principal_id) where archived_at is null;
create index projects_last_update_idx on public.projects (ultima_atualizacao) where archived_at is null;

create table public.project_members (
  project_id uuid not null references public.projects (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  archived_at timestamptz,
  primary key (project_id, user_id)
);

create index project_members_user_idx on public.project_members (user_id) where archived_at is null;

create table public.project_stages (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  descricao text,
  status public.stage_status not null default 'PENDENTE',
  ordem integer not null check (ordem >= 0),
  responsavel_id uuid references public.profiles (id) on delete restrict,
  data_inicio date,
  data_conclusao date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create unique index project_stages_order_active_uidx on public.project_stages (project_id, ordem) where archived_at is null;
create index project_stages_project_idx on public.project_stages (project_id) where archived_at is null;

create table public.checklist_items (
  id uuid primary key default extensions.gen_random_uuid(),
  stage_id uuid not null references public.project_stages (id) on delete restrict,
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  descricao text,
  is_completed boolean not null default false,
  responsavel_id uuid references public.profiles (id) on delete restrict,
  due_date date,
  completed_at timestamptz,
  completed_by uuid references public.profiles (id) on delete restrict,
  ordem integer not null check (ordem >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint checklist_completion_fields_check check (
    (is_completed and completed_at is not null)
    or (not is_completed and completed_at is null and completed_by is null)
  )
);

create unique index checklist_order_active_uidx on public.checklist_items (stage_id, ordem) where archived_at is null;
create index checklist_stage_idx on public.checklist_items (stage_id) where archived_at is null;
create index checklist_responsible_idx on public.checklist_items (responsavel_id) where archived_at is null;
create index checklist_pending_due_idx on public.checklist_items (due_date) where not is_completed and archived_at is null;

create table public.project_commits (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  user_id uuid references public.profiles (id) on delete restrict,
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  descricao text,
  tipo public.commit_type not null default 'ATUALIZACAO',
  origem public.event_source not null default 'MANUAL',
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index project_commits_timeline_idx on public.project_commits (project_id, created_at desc);

create table public.project_history (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  user_id uuid references public.profiles (id) on delete restrict,
  acao text not null,
  entidade_tipo text not null,
  entidade_id uuid,
  campo text,
  valor_anterior jsonb,
  valor_novo jsonb,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index project_history_timeline_idx on public.project_history (project_id, created_at desc);

create table public.project_comments (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  conteudo text not null check (char_length(btrim(conteudo)) between 1 and 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create index project_comments_project_idx on public.project_comments (project_id, created_at desc) where archived_at is null;

create table public.related_conversations (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  url text not null check (url ~ '^https?://'),
  origem public.conversation_origin not null default 'OUTRO',
  descricao text,
  created_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  archived_at timestamptz
);

create index related_conversations_project_idx on public.related_conversations (project_id) where archived_at is null;

create table public.related_links (
  id uuid primary key default extensions.gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete restrict,
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  url text not null check (url ~ '^https?://'),
  tipo public.link_type not null default 'OUTRO',
  descricao text,
  created_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  archived_at timestamptz
);

create index related_links_project_idx on public.related_links (project_id) where archived_at is null;

create table public.inbox_items (
  id uuid primary key default extensions.gen_random_uuid(),
  titulo text not null check (char_length(btrim(titulo)) between 2 and 180),
  descricao text,
  company_id uuid references public.companies (id) on delete restrict,
  unit_id uuid references public.units (id) on delete restrict,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  converted_to_project_id uuid unique references public.projects (id) on delete restrict,
  status public.inbox_status not null default 'NOVO',
  archived_at timestamptz,
  constraint inbox_conversion_state_check check (
    (status = 'CONVERTIDO' and converted_to_project_id is not null)
    or (status <> 'CONVERTIDO' and converted_to_project_id is null)
  )
);

create index inbox_status_created_idx on public.inbox_items (status, created_at desc) where archived_at is null;
