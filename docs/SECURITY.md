# Segurança do CT Workspace

## Variáveis de ambiente

O arquivo `.env.local` é local, está ignorado pelo Git e não deve ser compartilhado por chat, commit, documentação ou logs.

### Permitidas no frontend

| Variável | Uso |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | URL pública do projeto Supabase |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Chave publicável usada pelo navegador com RLS |

A chave publicável não concede privilégios administrativos. A autorização continua dependendo da sessão do usuário e das policies RLS.

### Exclusivamente server-side

| Variável | Uso na Fase 0.5 |
| --- | --- |
| `SUPABASE_SECRET_KEY` | Cliente administrativo isolado para criar/remover usuários de teste e consultar resultados de homologação |
| `SUPABASE_ACCESS_TOKEN` | Autenticação da Supabase CLI na Management API |
| `SUPABASE_PROJECT_REF` | Identificador do projeto remoto usado pelo `supabase link` |
| `SUPABASE_DB_PASSWORD` | Conexão da CLI com o PostgreSQL remoto |

Nenhuma dessas variáveis pode ter prefixo `NEXT_PUBLIC_`. A chave secreta ignora RLS e nunca deve ser importada por Client Components, pelo cliente SSR normal ou pelo proxy de sessão.

As chaves legadas `anon` e `service_role` não são a configuração preferencial deste projeto. A versão atual utiliza chaves `publishable` e `secret`.

## Autenticação e sessão

- Supabase Auth valida credenciais e emite a sessão.
- O proxy renova cookies quando necessário.
- O layout protegido confirma o usuário com `auth.getUser()` no servidor.
- Rotas privadas redirecionam usuários sem sessão para `/login`.
- Um usuário autenticado com perfil inativo não recebe o workspace e não lê dados de negócio por RLS.
- Logout revoga a sessão local e o acesso à área protegida deve voltar a exigir autenticação.

## Perfil automático

O trigger `on_auth_user_created` chama `handle_new_user()` após a criação em `auth.users`. O perfil nasce com:

- o mesmo UUID do usuário Auth;
- email correspondente;
- papel `MEMBRO`;
- `ativo = false`.

A criação do usuário e o trigger participam da mesma transação. Uma falha na criação do perfil deve impedir a conclusão do cadastro, evitando um usuário Auth criado silenciosamente sem perfil.

## Papéis

- `ADMIN`: administração do workspace e gestão dos dados.
- `GESTOR`: gestão de projetos, execução, Inbox e projetos técnicos; não administra papéis.
- `MEMBRO`: leitura de projetos autorizados, commits manuais permitidos e conclusão de checklist atribuído.

As permissões da interface não são barreira de segurança. Policies e triggers no PostgreSQL são a fonte efetiva de autorização.

## Row Level Security

Todas as tabelas públicas da fundação têm RLS habilitado. Não existem grants de `DELETE` para clientes autenticados; entidades históricas usam arquivamento lógico.

Projetos técnicos independentes são visíveis somente a `ADMIN`/`GESTOR`. Um `MEMBRO` lê `development_projects` apenas quando o registro está ligado a um projeto estratégico que já pode acessar.

## Primeiro administrador

O primeiro cadastro nunca recebe `ADMIN` automaticamente. O procedimento controlado para um ambiente novo é:

1. Criar o usuário pelo Supabase Auth.
2. Confirmar que `public.profiles` contém o mesmo UUID, `MEMBRO` e `ativo = false`.
3. Em uma sessão administrativa no SQL Editor, atualizar exatamente esse perfil para `ADMIN` e `ativo = true` usando o UUID obtido de `auth.users`.
4. Verificar que exatamente uma linha foi atualizada e testar o login.

Esse procedimento é repetível e não requer adicionar lógica de bootstrap à aplicação.

## Proteção contra escalada de privilégios

- `protect_profile_security_fields()` impede usuários não administradores de alterar `role`, `ativo`, `email` ou `id` do perfil.
- Policies impedem `GESTOR` e `MEMBRO` de administrar perfis de terceiros.
- `protect_created_by_immutable()` impede sessões autenticadas de reatribuir `created_by` depois da criação.
- `sync_checklist_completion()` preenche `completed_at` e `completed_by` com o momento e o usuário da transição; alterações parciais posteriores nesses campos são bloqueadas.
- A homologação deve testar chamadas diretas ao Data API, inclusive updates parciais, sem depender da sidebar.

Qualquer possibilidade real de autopromoção, alteração indevida de autoria ou leitura fora do escopo bloqueia a Fase 0.5.

## `SECURITY DEFINER` e `search_path`

`SECURITY DEFINER` só é aceitável para funções que precisam atravessar RLS ou operar como parte confiável de um trigger. Essas funções usam `set search_path = ''` e referências qualificadas por schema para evitar resolução de objetos controlados por usuários.

Os helpers de autorização usados pelas policies ficam no schema não exposto `private`. O papel `authenticated` possui somente `USAGE` nesse schema e `EXECUTE` nos seis helpers necessários para a avaliação interna do RLS; `anon` e `PUBLIC` não possuem essas permissões. Como o schema não integra a Data API, os helpers não são publicados como RPC.

Funções internas de escrita automática permanecem sem `EXECUTE` para `anon`, `authenticated` ou `PUBLIC`. Elas são chamadas apenas por triggers ou por outras funções controladas.

## Secrets

- `.env`, `.env.local` e variantes permanecem ignorados.
- `.env.example` contém somente nomes e placeholders.
- Nenhum valor secreto deve ser impresso por scripts de teste.
- Logs devem registrar apenas presença/ausência e resultados sanitizados.
- Se uma chave secreta for exposta, ela deve ser revogada e substituída imediatamente.

## Limitações atuais

- A fundação ainda não foi homologada em produção.
- Não há recuperação de senha na interface.
- Não há convite/autoadministração de usuários.
- Não há matriz de participantes própria para projetos técnicos independentes.
- Não há integração GitHub, CI/CD, deploy ou agente local.

## Recomendações para produção

Estas recomendações pertencem à futura Fase 0.75 e não são implementadas agora:

- separar projetos Supabase de homologação e produção;
- configurar URLs e redirects permitidos por ambiente;
- exigir HTTPS e revisar cookies;
- rotacionar e armazenar segredos em cofre apropriado;
- habilitar observabilidade, alertas e retenção de logs sem dados sensíveis;
- definir backup, restauração e rollback testados;
- repetir testes positivos e negativos de RLS antes de cada release;
- revisar funções `SECURITY DEFINER` após mudanças de schema.
