# CT Workspace

Aplicação interna para acompanhar os projetos da CT Ítalo Vieira, Netmitt e futuras empresas da holding. O objetivo é mostrar com rapidez o que está em andamento, parado, pendente e concluído, preservando uma timeline útil de alterações.

## Estado atual

Fase 0 — Fundação. Esta fase cobre documentação, schema Supabase, autenticação e a casca inicial da aplicação. Funcionalidades completas de projeto serão implementadas nas fases seguintes.

## Stack

- Next.js com App Router e TypeScript
- Tailwind CSS
- Supabase Auth, PostgreSQL e RLS
- Supabase Realtime somente onde houver benefício operacional

## Pré-requisitos

- Node.js 24 (validado com 24.14.1)
- npm 11 ou superior
- Git
- Conta/projeto no Supabase ou Supabase CLI para ambiente local

## Configuração local

1. Instale as dependências:

   ```bash
   npm install
   ```

2. Copie `.env.example` para `.env.local` e preencha:

   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://seu-projeto.supabase.co
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_sua-chave
   ```

   Essas duas variáveis são públicas e podem ser utilizadas pelo frontend quando o RLS está habilitado. Para a homologação remota, `.env.local` também pode conter `SUPABASE_SECRET_KEY`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` e `SUPABASE_DB_PASSWORD`. Todas são exclusivamente server-side e nunca devem usar o prefixo `NEXT_PUBLIC_`. Consulte [Segurança](docs/SECURITY.md) antes de configurá-las.

3. Aplique as migrations e o seed com Supabase CLI:

   ```bash
   npx supabase link --project-ref SEU_PROJECT_REF
   npx supabase db push
   npx supabase db seed
   ```

   Para desenvolvimento inteiramente local, use `npx supabase start` e `npx supabase db reset`.

4. No primeiro acesso, crie um usuário no Supabase Auth. Por segurança, o perfil nasce como `MEMBRO` e inativo. Confirme que o trigger criou exatamente um registro em `public.profiles` e promova o primeiro administrador por uma sessão administrativa controlada no SQL Editor:

   ```sql
   begin;

   do $bootstrap$
   declare
     bootstrap_email text := 'admin-homologacao@example.com';
     affected_rows integer;
   begin
     update public.profiles
     set ativo = true, role = 'ADMIN'
     where id = (
       select id
       from auth.users
       where lower(email) = lower(bootstrap_email)
     );

     get diagnostics affected_rows = row_count;

     if affected_rows <> 1 then
       raise exception 'Bootstrap cancelado: esperado 1 perfil, encontrados %.', affected_rows;
     end if;
   end
   $bootstrap$;

   commit;
   ```

   Substitua apenas o email de homologação antes de executar. O bloco cancela a transação se não encontrar exatamente um perfil. Nunca implemente a regra “primeiro cadastro vira administrador” e nunca execute essa promoção usando a chave publicável.

5. Execute a aplicação:

   ```bash
   npm run dev
   ```

6. Abra `http://localhost:3000`.

## Scripts

```bash
npm run dev
npm run lint
npm run build
npm run start
```

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [Banco de dados](docs/DATABASE.md)
- [Roadmap](docs/ROADMAP.md)
- [Segurança](docs/SECURITY.md)

## Segurança

- Nunca versione `.env`, `.env.local`, tokens ou chaves `service_role`.
- A chave publicável é usada com RLS habilitado; ela não substitui policies.
- O fluxo normal da aplicação não precisa de chave secreta nem da `service_role` legada.
- Não faça push para um repositório remoto sem autorização.

## Commits sugeridos por fase

```text
feat: initialize CT Workspace
feat: add project management database
feat: add project checklist system
feat: add project commit timeline
feat: add project inbox
```
