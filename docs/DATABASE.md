# Banco de dados do CT Workspace

## Convenções

- PostgreSQL no Supabase.
- Chaves primárias UUID geradas por `gen_random_uuid()`.
- Datas técnicas em `timestamptz`; datas de negócio sem horário em `date`.
- Nomes SQL em `snake_case` e valores de enums em maiúsculas.
- `created_at` e `updated_at` são preenchidos pelo banco.
- Exclusão histórica é evitada; entidades principais possuem `archived_at` ou estado equivalente.
- Valores exibidos em português são mapeados na interface; o banco preserva códigos estáveis.

## Enums

| Enum | Valores |
| --- | --- |
| `app_role` | `ADMIN`, `GESTOR`, `MEMBRO` |
| `project_status` | `BACKLOG`, `EM_PLANEJAMENTO`, `EM_ANDAMENTO`, `AGUARDANDO`, `BLOQUEADO`, `CONCLUIDO`, `ARQUIVADO` |
| `project_priority` | `BAIXA`, `MEDIA`, `ALTA`, `CRITICA` |
| `stage_status` | `PENDENTE`, `EM_ANDAMENTO`, `CONCLUIDA`, `BLOQUEADA` |
| `commit_type` | `ATUALIZACAO`, `ETAPA_CONCLUIDA`, `CHECKLIST`, `STATUS`, `DECISAO`, `DOCUMENTO`, `COMENTARIO`, `CONCLUSAO` |
| `event_source` | `MANUAL`, `SISTEMA`, `INTEGRACAO` |
| `conversation_origin` | `CHATGPT`, `REUNIAO`, `WHATSAPP`, `OUTRO` |
| `link_type` | `DOCUMENTO`, `PLANILHA`, `DRIVE`, `GITHUB`, `CANVA`, `PDF`, `OUTRO` |
| `inbox_status` | `NOVO`, `ANALISANDO`, `CONVERTIDO`, `DESCARTADO` |
| `development_project_status` | `PLANEJAMENTO`, `ATIVO`, `PAUSADO`, `CONCLUIDO`, `ARQUIVADO` |
| `development_environment` | `LOCAL`, `DESENVOLVIMENTO`, `STAGING`, `PRODUCAO` |

## Tabelas

### `profiles`

Perfil operacional ligado a `auth.users`.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `id` | uuid | PK e FK `auth.users(id)` |
| `nome` | text | obrigatório |
| `email` | text | obrigatório, único |
| `avatar_url` | text | opcional |
| `cargo` | text | opcional |
| `role` | app_role | padrão `MEMBRO` |
| `ativo` | boolean | padrão `false` |
| `created_at` | timestamptz | automático |
| `updated_at` | timestamptz | automático |

### `companies`

Empresas da organização.

Campos: `id`, `nome`, `sigla`, `ativo`, `created_at`, `updated_at`, `archived_at`.

### `units`

Unidades de uma empresa.

Campos: `id`, `company_id`, `nome`, `sigla`, `ativo`, `created_at`, `updated_at`, `archived_at`.

Restrição única: `(company_id, nome)` e `(company_id, sigla)`.

### `areas`

Áreas dinâmicas. Pertencem a uma empresa e podem opcionalmente ser específicas de uma unidade.

Campos: `id`, `company_id`, `unit_id`, `nome`, `sigla`, `ativo`, `created_at`, `updated_at`, `archived_at`.

### `projects`

Registro central do sistema.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `id` | uuid | PK |
| `codigo` | text | único, formato simples e validado |
| `titulo` | text | obrigatório |
| `descricao` | text | opcional |
| `company_id` | uuid | FK `companies` |
| `unit_id` | uuid | FK `units` |
| `area_id` | uuid | FK `areas` |
| `status` | project_status | padrão `BACKLOG` |
| `prioridade` | project_priority | padrão `MEDIA` |
| `responsavel_principal_id` | uuid | FK `profiles`, opcional |
| `data_inicio` | date | obrigatório |
| `data_prevista` | date | opcional |
| `data_conclusao` | date | opcional |
| `progresso` | smallint | entre 0 e 100 |
| `progresso_manual` | boolean | indica projeto sem checklist |
| `proxima_acao` | text | opcional |
| `ultima_atualizacao` | timestamptz | automático |
| `created_at`, `updated_at` | timestamptz | automáticos |
| `created_by` | uuid | FK `profiles` |
| `archived_at` | timestamptz | soft delete |

Constraints garantem que unidade e área sejam coerentes com a empresa por meio de triggers de validação. Índices cobrem filtros por empresa, unidade, área, status, prioridade, responsável e atualização.

### `project_members`

Participantes autorizados e responsáveis adicionais.

Campos: `project_id`, `user_id`, `created_at`, `created_by`. PK composta `(project_id, user_id)`.

### `project_stages`

Campos: `id`, `project_id`, `titulo`, `descricao`, `status`, `ordem`, `responsavel_id`, `data_inicio`, `data_conclusao`, `created_at`, `updated_at`, `archived_at`.

### `checklist_items`

Campos: `id`, `stage_id`, `titulo`, `descricao`, `is_completed`, `responsavel_id`, `due_date`, `completed_at`, `completed_by`, `ordem`, `created_at`, `updated_at`, `archived_at`.

### `project_commits`

Timeline legível do projeto.

Campos: `id`, `project_id`, `user_id`, `titulo`, `descricao`, `tipo`, `origem`, `metadata` (`jsonb`), `created_at`.

`origem` diferencia commit manual, evento do sistema e integração futura.

### `project_history`

Auditoria estruturada para alterações importantes.

Campos: `id`, `project_id`, `user_id`, `acao`, `entidade_tipo`, `entidade_id`, `campo`, `valor_anterior` (`jsonb`), `valor_novo` (`jsonb`), `metadata` (`jsonb`), `created_at`.

### `project_comments`

Comentários livres, separados de commits para permitir evolução futura.

Campos: `id`, `project_id`, `user_id`, `conteudo`, `created_at`, `updated_at`, `archived_at`.

### `related_conversations`

Campos: `id`, `project_id`, `titulo`, `url`, `origem`, `descricao`, `created_at`, `created_by`, `archived_at`.

### `related_links`

Campos: `id`, `project_id`, `titulo`, `url`, `tipo`, `descricao`, `created_at`, `created_by`, `archived_at`.

### `inbox_items`

Campos: `id`, `titulo`, `descricao`, `company_id`, `unit_id`, `created_by`, `created_at`, `updated_at`, `converted_to_project_id`, `status`, `archived_at`.

### `development_projects`

Fundação dos projetos técnicos. O vínculo estratégico é opcional e fica nesta tabela para permitir vários projetos técnicos por projeto principal.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `id` | uuid | PK |
| `titulo` | text | obrigatório |
| `descricao` | text | opcional |
| `project_id` | uuid | FK opcional `projects`, `ON DELETE RESTRICT` |
| `repository_url` | text | opcional, URL HTTP(S) |
| `repository_provider` | text | opcional, código estável como `GITHUB` |
| `repository_owner` | text | opcional |
| `repository_name` | text | opcional |
| `default_branch` | text | opcional |
| `status` | development_project_status | padrão `PLANEJAMENTO` |
| `ambiente` | development_environment | padrão `LOCAL` |
| `ultima_atividade` | timestamptz | snapshot opcional |
| `ultimo_commit_sha` | text | snapshot opcional, hexadecimal entre 7 e 64 caracteres |
| `ultimo_commit_titulo` | text | snapshot opcional |
| `ultimo_commit_autor` | text | snapshot opcional |
| `ultimo_commit_data` | timestamptz | snapshot opcional |
| `created_at`, `updated_at` | timestamptz | automáticos |
| `created_by` | uuid | FK `profiles` |
| `archived_at` | timestamptz | soft delete opcional |

Os metadados de repositório podem ser cadastrados manualmente no futuro. Os campos `ultimo_commit_*` não substituem uma futura entidade de Git commits; representam somente o último estado conhecido.

## Relações

```text
auth.users 1---1 profiles
companies 1---N units
companies 1---N areas
units     1---N areas (opcional)
companies 1---N projects
units     1---N projects
areas     1---N projects
profiles  1---N projects (responsável/criador)
projects  N---N profiles (project_members)
projects  1---N project_stages
project_stages 1---N checklist_items
projects  1---N project_commits
projects  1---N project_history
projects  1---N project_comments
projects  1---N related_conversations
projects  1---N related_links
inbox_items 0..1---1 projects (após conversão)
projects  1---N development_projects (vínculo opcional no lado técnico)
profiles  1---N development_projects (criador)
```

## Integridade e automações no banco

### `updated_at`

Trigger comum atualiza `updated_at` antes de cada alteração.

### Perfil após cadastro

Trigger em `auth.users` cria `profiles` com email/nome disponível, papel `MEMBRO` e `ativo = false`. Isso evita conceder acesso automático a novos cadastros.

### Progresso

- Se existir ao menos um checklist não arquivado, o progresso é a porcentagem inteira de itens concluídos.
- Sem checklist, `progresso_manual = true` permite edição de `progresso`.
- Mudanças em checklist recalculam o projeto na mesma transação.

### Histórico

Triggers registram apenas eventos relevantes: criação, status, prioridade, responsável, próxima ação, conclusão/reabertura, etapa criada/concluída e checklist concluído/reaberto.

O usuário atual é obtido por `auth.uid()`. Processos de sistema podem informar origem e metadata, mas não simulam outro usuário.

### Histórico técnico

Alterações em `development_projects` não são gravadas em `project_history`: a tabela atual pertence ao contexto estratégico e um projeto técnico pode não ter `project_id`. A futura página de Histórico deverá usar uma entidade técnica própria ou um modelo de eventos compartilhado definido junto da fase Desenvolvimento/GitHub. A fundação evita registrar eventos técnicos incompletos ou misturar os dois domínios.

## RLS do MVP

Todas as tabelas públicas têm RLS habilitado.

### Funções auxiliares

- `is_active_user()` — usuário possui perfil ativo.
- `current_user_role()` — retorna papel do perfil.
- `is_admin()` — perfil ativo e `ADMIN`.
- `can_manage_projects()` — perfil ativo e `ADMIN`/`GESTOR`.
- `can_access_project(project_id)` — admin/gestor, criador, responsável principal ou participante.

As funções usam `security definer`, `search_path` fixo e não ficam disponíveis anonimamente.

### Matriz resumida

| Recurso | ADMIN | GESTOR | MEMBRO |
| --- | --- | --- | --- |
| Empresas/unidades/áreas | CRUD | leitura | leitura |
| Perfis | CRUD | leitura de ativos | próprio perfil + ativos necessários |
| Projetos | CRUD | criar/editar/arquivar | ler autorizados |
| Etapas/commits/links | CRUD | CRUD | ler autorizados; criar commit permitido |
| Checklist | CRUD | CRUD | ler autorizados; atualizar item atribuído |
| Inbox | CRUD | CRUD | sem acesso no MVP |
| Projetos técnicos | CRUD lógico | criar/editar/arquivar | ler somente quando vinculado a projeto autorizado |

`DELETE` físico não é concedido pelas policies de cliente para tabelas históricas.

### Catálogo de policies

- `profiles_select` e `profiles_update`: leitura do próprio perfil, diretório ativo e administração; campos de segurança são protegidos por trigger.
- `companies_*`, `units_*` e `areas_*`: leitura por usuários ativos e escrita somente por administradores.
- `projects_*`: leitura por acesso ao projeto e escrita por administradores/gestores.
- `project_members_*` e `stages_*`: leitura vinculada ao projeto e escrita por administradores/gestores.
- `checklist_*`: leitura vinculada ao projeto; administradores/gestores editam, e membros alteram somente a conclusão de itens atribuídos.
- `commits_select` e `commits_insert_manual`: timeline visível aos participantes e commit manual identificado pelo usuário atual.
- `history_select`: histórico somente leitura para participantes autorizados.
- `comments_*`: leitura por participantes, criação pelo autor e edição pelo autor ou gestão.
- `conversations_*` e `links_*`: leitura por participantes e escrita por administradores/gestores.
- `inbox_*`: acesso restrito a administradores/gestores.
- `development_projects_*`: administradores/gestores leem e gerenciam; membros leem somente registros ligados a projetos estratégicos já autorizados.

Não há policy de cliente para exclusão física nem para inserção direta em `project_history`. Eventos automáticos são produzidos por funções internas com `search_path` fixo.

## Seed

O seed é idempotente e cria:

- CT Ítalo Vieira (`CT`) e a unidade CT Ítalo Vieira (`CT`);
- Netmitt (`NET`) e as unidades Campo Bom (`CB`), Canudos (`CAN`) e Rondônia (`RO`);
- as áreas Operação, Comercial, Professores, Jornada do Aluno, Gestão, Sistemas, Marketing, Financeiro, RH, Treinamento, Infraestrutura e Estratégia para cada empresa.

Nenhum usuário ou projeto fictício é criado.

O seed também não cria projetos técnicos. CT Workspace, Sistema NextFit / ERP Academia, DeskcommCRM e App do aluno são apenas exemplos documentais.

## Migrations planejadas

1. `0001_initial_schema.sql`: extensões, enums, tabelas, constraints e índices.
2. `0002_functions_and_triggers.sql`: timestamps, perfil, validações, progresso e eventos automáticos.
3. `0003_rls_policies.sql`: RLS, funções auxiliares e policies.
4. `0004_development_projects.sql`: enums, tabela, índices, timestamp, RLS e grants da fundação de Desenvolvimento.

## Decisões para fases futuras

- RPC transacional de conversão da Inbox.
- RPC de conclusão/reabertura com confirmação de pendências.
- Idempotency keys para commits externos.
- Escopo de acesso por empresa/unidade, caso papéis globais deixem de ser suficientes.
- Participantes próprios para projetos técnicos independentes, se necessário.
- Entidades detalhadas de Git commits, branches, Pull Requests, Issues e deploys quando a integração GitHub for implementada.
- Relação opcional entre Git Commit e Workspace Commit após definição da sincronização.
