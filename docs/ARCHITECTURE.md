# Arquitetura do CT Workspace

## Objetivo

O CT Workspace é uma aplicação interna para registrar projetos, acompanhar sua execução e preservar um histórico legível das decisões e alterações relevantes. O MVP prioriza consulta rápida, operação simples e segurança por usuário autenticado.

## Princípios

- Monólito modular em Next.js; não há microsserviços.
- Supabase é a fonte de verdade para autenticação, PostgreSQL e Realtime.
- Regras de autorização ficam no banco por meio de Row Level Security (RLS), não apenas na interface.
- SQL versionado em migrations; nenhuma tabela depende de criação manual.
- Dados de negócio importantes são arquivados, não removidos fisicamente.
- Commits manuais e eventos automáticos compartilham uma timeline, mas têm origem identificável.
- Realtime será aplicado apenas a dados em que atualização simultânea agrega valor, começando pela timeline e pelos itens de checklist.
- A aplicação usa Server Components por padrão e Client Components somente onde houver interação ou estado local.

## Premissas da Fase 0

1. O MVP atende uma única organização interna, com múltiplas empresas e unidades.
2. Todos os usuários autenticados e ativos pertencem a essa organização.
3. `ADMIN`, `GESTOR` e `MEMBRO` são papéis globais no MVP.
4. A restrição de projetos visíveis para membros será representada por uma tabela de participantes do projeto.
5. Um perfil é criado automaticamente quando um usuário entra no Supabase Auth. Um administrador deve ativá-lo e ajustar seu papel.
6. A exclusão física de projetos, etapas, commits e itens relacionados não faz parte da interface do MVP.
7. A Fase 0 entrega a fundação técnica e uma casca autenticada; os CRUDs de negócio começam na Fase 1.

## Visão geral

```text
Navegador
  |
  v
Next.js App Router
  |- Server Components: leitura inicial e páginas
  |- Server Actions/Route Handlers: mutações validadas
  |- Client Components: formulários e interações locais
  |
  v
Supabase
  |- Auth: sessão e identidade
  |- PostgreSQL: dados e regras
  |- RLS: autorização por perfil e participação
  `- Realtime: timeline/checklists quando habilitado
```

Não haverá backend separado. Operações iniciadas pelo navegador usam o cliente Supabase com a sessão do usuário; operações de servidor preservam a mesma identidade por cookies. A chave `service_role` não será exposta ao frontend.

## Estrutura de pastas

```text
app/
  (auth)/
    login/
  (workspace)/
    dashboard/
    inbox/
    projetos/
    desenvolvimento/          # futuro; nenhuma rota implementada na fundação
    empresas/
    unidades/
    areas/
    equipe/
    configuracoes/
    layout.tsx
  auth/
    callback/
  api/                       # somente endpoints internos/futuros autenticados
components/
  auth/
  layout/
  ui/                        # componentes visuais reutilizáveis e simples
features/
  projects/
  stages/
  checklists/
  commits/
  inbox/
  development/                # futuro módulo técnico
  organization/
lib/
  supabase/
    client.ts
    server.ts
    proxy.ts
  auth/
  constants/
  utils/
supabase/
  migrations/
  seed.sql
docs/
  ARCHITECTURE.md
  DATABASE.md
  ROADMAP.md
```

As pastas em `features/` serão adicionadas à medida que cada fase começar. Não serão criadas camadas abstratas sem uso real.

## Limites dos módulos

### Autenticação

- Supabase Auth gerencia credenciais e sessões.
- `public.profiles` contém os dados operacionais do usuário.
- O proxy renova cookies; o layout protegido valida a sessão no servidor.
- Usuário sem sessão é redirecionado para `/login`.
- Usuário inativo pode autenticar no provedor, mas não acessa os dados protegidos pelas policies.

### Organização

Empresas, unidades e áreas são dados dinâmicos. Áreas podem ser globais para uma empresa ou específicas de uma unidade. A interface administrativa será entregue na Fase 1.

### Projetos e execução

Projetos pertencem a uma empresa, unidade e área. Etapas pertencem ao projeto e itens de checklist pertencem à etapa. Participantes adicionais ficam em `project_members`.

### Development Projects

O módulo Desenvolvimento acompanhará projetos de software construídos com Codex ou outras ferramentas sem transformar o CT Workspace em uma ferramenta de engenharia. `development_projects` representa o projeto técnico e pode apontar opcionalmente para um projeto estratégico em `projects`.

```text
projects 1 ---- N development_projects
                 project_id pode ser nulo
```

Assim, um projeto estratégico pode não ter projeto técnico, ter um ou ter vários; um projeto técnico também pode existir sem vínculo estratégico. A relação fica no lado técnico para não limitar a quantidade de sistemas ligados à mesma iniciativa.

Os campos de repositório e último commit são apenas um snapshot fundamental para cadastro/sincronização futura. Não existe chamada ao GitHub, OAuth, sincronização, tabela de Git commits, branches, Pull Requests, Issues ou deploys nesta extensão.

O fluxo conceitual futuro é:

```text
Codex -> Git local -> GitHub -> CT Workspace
```

O GitHub será a fonte oficial do código versionado. O Workspace não tentará ler sessões, conversas ou estado interno do Codex. Alterações locais ainda não commitadas também ficam fora do MVP; um agente local ou CLI poderá ser avaliado posteriormente.

#### Workspace Commit e Git Commit

- **Workspace Commit** (`project_commits`): decisão ou alteração relevante de gestão, como a aprovação de um checklist.
- **Git Commit**: alteração versionada no código-fonte, identificada por SHA, autor, mensagem e data.

Eles não são equivalentes. Uma fase futura poderá relacioná-los, mas a fundação não cria uma tabela completa de Git commits antes de existir uma integração real que determine identidade, paginação, sincronização e retenção.

Exemplos de futuros projetos técnicos, apenas documentais: CT Workspace, Sistema NextFit / ERP Academia, DeskcommCRM e App do aluno. O seed não cria nenhum deles.

### Timeline e auditoria

- `project_commits` reúne atualizações relevantes, manuais ou automáticas.
- `project_history` registra mudanças estruturadas com valores anterior/novo.
- Triggers geram eventos para mudanças importantes e atualizam `ultima_atualizacao`.
- Comentários ficam em tabela própria e podem originar um commit automático.

### Inbox

Itens existem antes de um projeto. A conversão deve ocorrer em uma transação SQL/RPC para criar o projeto e marcar o item como convertido sem estado intermediário.

## Fluxos importantes

### Conclusão de checklist

1. Usuário autenticado atualiza o item.
2. RLS valida permissão.
3. Trigger preenche `completed_at`/`completed_by`.
4. Trigger registra evento útil na timeline.
5. O progresso do projeto é recalculado com todos os checklists do projeto.

### Conclusão de projeto

1. A interface consulta a quantidade de itens pendentes.
2. Se houver pendências, exige confirmação explícita.
3. A mutação chama uma função transacional com a confirmação.
4. A função define status, conclusão e progresso, registra autor e commit automático.

### Reabertura

Uma função transacional altera o status para `EM_ANDAMENTO`, limpa `data_conclusao` no estado atual e preserva a data anterior em `project_history` e no commit automático.

## Rotas e telas planejadas

| Rota | Tela | Fase | Acesso |
| --- | --- | --- | --- |
| `/login` | Entrada | 0 | Público |
| `/auth/callback` | Callback de autenticação | 0 | Público |
| `/dashboard` | Indicadores e atenção | 0/5 | Autenticado |
| `/inbox` | Ideias e conversão | 4 | Admin/Gestor |
| `/projetos` | Lista, busca e filtros | 1 | Autenticado |
| `/projetos/novo` | Criação de projeto | 1 | Admin/Gestor |
| `/projetos/[id]` | Visão geral do projeto | 1 | Autorizado |
| `/projetos/[id]/editar` | Edição do projeto | 1 | Admin/Gestor |
| `/desenvolvimento` | Lista de projetos técnicos | Desenvolvimento/GitHub | Conforme RLS |
| `/desenvolvimento/[id]` | Projeto técnico | Desenvolvimento/GitHub | Conforme RLS |
| `/empresas` | Administração de empresas | 1 | Admin |
| `/unidades` | Administração de unidades | 1 | Admin |
| `/areas` | Administração de áreas | 1 | Admin |
| `/equipe` | Perfis, papéis e ativação | 1/6 | Admin |
| `/configuracoes` | Preferências do workspace | 6 | Admin |

A tela de projeto usará seções/abas para visão geral, etapas, checklist, commits, conversas, links e histórico sem criar uma rota independente para cada aba no MVP.

As rotas de Desenvolvimento são somente planejamento arquitetural e não existem na aplicação atual. A sidebar já suporta itens desabilitados e mostra `Desenvolvimento` como futuro módulo, sem criar página vazia.

A futura listagem deverá apresentar projeto, status, projeto estratégico relacionado, repositório, branch principal, último commit, última atividade e ambiente. A futura página técnica prevê as seções Visão geral, Repositório, Commits, Branches, Pull Requests, Issues, Deploy, Projeto relacionado e Histórico.

## Componentes principais planejados

### Fundação

- `AppSidebar`: navegação filtrada pelo papel do usuário.
- `MobileNavigation`: acesso responsivo às rotas principais.
- `UserMenu`: identidade e saída.
- `PageHeader`: título, descrição e ações da página.
- `StatusBadge`: rótulos amigáveis e cores consistentes.
- `PriorityBadge`: identificação de prioridade.
- `ProgressBar`: progresso acessível.
- `EmptyState`, `LoadingState` e `ErrorState`: estados consistentes.

### Projetos

- `ProjectFilters`
- `ProjectTable`
- `ProjectForm`
- `ProjectSummary`
- `NextActionCard`
- `ForgottenProjectIndicator`

### Execução e histórico

- `StageList` e `StageForm`
- `ChecklistList`, `ChecklistItem` e `ChecklistForm`
- `CommitTimeline` e `CommitForm`
- `ProjectHistoryList`
- `ProjectCompletionDialog`

### Organização

- `InboxList`, `InboxForm` e `ConvertInboxDialog`
- `RelatedConversationList`
- `RelatedLinkList`
- formulários administrativos de empresa, unidade, área e perfil

### Desenvolvimento (futuro)

- `DevelopmentProjectTable` e filtros da listagem técnica
- `DevelopmentProjectSummary`
- seções de repositório, commits, branches, Pull Requests, Issues, deploy e histórico

Esses componentes são apenas limites planejados; nenhum foi implementado nesta extensão.

## Estratégia de dados no Next.js

- Leituras iniciais: Server Components com cliente Supabase de servidor.
- Mutações: Server Actions para formulários da aplicação, com validação e retorno tipado.
- Route Handlers: reservados para integrações autenticadas e callbacks.
- Validação: schemas próximos à feature; o banco continua aplicando constraints.
- Cache: dados autenticados e sensíveis não usam cache compartilhado. Revalidação será pontual após mutações.

## Segurança

- Cookies de sessão renovados no proxy.
- RLS habilitado em todas as tabelas de negócio.
- Policies usam funções auxiliares `security definer` com `search_path` fixo.
- Chaves públicas podem ir ao navegador; `service_role` permanece apenas em ambiente seguro e não é necessária para o fluxo normal.
- Links externos são dados, não HTML; devem ser renderizados com escaping padrão e validação de URL.
- Toda operação futura por API exige usuário autenticado e as mesmas regras de autorização.

## Realtime

Não será habilitado indiscriminadamente. Candidatos iniciais:

- novos commits na timeline de um projeto aberto;
- conclusão/reabertura de checklist em uma tela compartilhada;
- atualização do progresso derivado.

Dashboard e listas usam atualização após navegação/mutação. Isso reduz complexidade e consumo de conexões.

## Preparação para IA e integrações

Uma futura camada de sugestão poderá produzir uma ação estruturada, mas nunca executá-la sem confirmação humana. Endpoints futuros usarão autenticação, validação, idempotência e registrarão o autor/origem. A arquitetura atual não inclui OpenAI, agentes nem tokens externos.

Para Desenvolvimento, uma integração futura com GitHub poderá consultar último commit, SHA, autor, data, commits recentes, branches, Pull Requests abertas, Issues abertas, última atividade e link do repositório. A autenticação, estratégia de sincronização e armazenamento detalhado serão decididas nessa fase, não na fundação.

Um futuro modelo de deploy poderá registrar ambiente, URL, servidor, versão, data do último deploy, commit utilizado e status. CI/CD, execução de deploy e infraestrutura de servidores permanecem fora do escopo atual.

## Decisões adiadas

- Provedor de email e regras de convite.
- Deploy e domínio da VPS.
- Realtime em produção.
- Políticas mais granulares por empresa/unidade.
- OAuth para integrações externas.
- Upload de arquivos.
- participação específica em projetos técnicos independentes.
- histórico detalhado de Git, deploys e estado local não commitado.

Essas decisões não bloqueiam a fundação local nem o schema do MVP.
