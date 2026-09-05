# Roadmap do CT Workspace

O roadmap organiza entregas pequenas e verificáveis. Uma fase só avança quando os critérios da anterior estiverem atendidos.

## Fase 0 — Fundação

### Escopo

- arquitetura, banco e roadmap documentados;
- Next.js, TypeScript e Tailwind configurados;
- integração base com Supabase;
- migrations, RLS e seed versionados;
- login, callback, logout e proteção de rotas;
- layout responsivo com sidebar;
- dashboard inicial vazio/estrutural;
- `.env.example`, scripts e instruções locais.

### Critérios de aceite

- `npm install`, `npm run lint` e `npm run build` funcionam;
- sem credenciais versionadas;
- migrations podem ser aplicadas em um projeto Supabase vazio;
- usuário sem sessão não acessa `/dashboard`;
- usuário autenticado e ativo visualiza o workspace;
- usuário inativo recebe mensagem clara e não lê dados de negócio;
- navegação funciona em desktop e mobile.

### Fora da fase

CRUD de empresas, projetos, etapas e Inbox; métricas reais do dashboard.

## Fase 1 — Projetos

### Escopo

- CRUD com arquivamento de empresas, unidades e áreas;
- administração básica de equipe;
- criação e edição de projetos;
- listagem, busca e filtros;
- página individual e participantes.

### Critérios de aceite

- relações empresa/unidade/área são validadas;
- código do projeto é único e legível;
- permissões distinguem administração, gestão e leitura autorizada;
- filtros podem ser combinados e preservados na URL.

Commit sugerido: `feat: add project management foundation`

## Fase 2 — Execução

### Escopo

- etapas ordenadas;
- itens de checklist;
- conclusão, reabertura e reordenação simples;
- progresso automático e fallback manual;
- próxima ação em destaque.

### Critérios de aceite

- progresso muda na mesma transação do checklist;
- itens podem ser criados, editados, arquivados, concluídos e reabertos;
- membro só atualiza tarefa atribuída quando autorizado.

Commit sugerido: `feat: add project stages and checklists`

## Fase 3 — Histórico

### Escopo

- commits manuais;
- timeline cronológica inversa;
- eventos automáticos úteis;
- conclusão com aviso de pendências;
- reabertura sem perda de histórico.

### Critérios de aceite

- origem manual/sistema é visível;
- conclusão e reabertura são transacionais;
- mudanças pequenas e irrelevantes não poluem a timeline;
- data anterior de conclusão permanece auditável.

Commit sugerido: `feat: add project commit timeline`

## Fase 4 — Organização

### Escopo

- Inbox;
- conversão transacional em projeto;
- conversas relacionadas;
- links e documentos externos;
- comentários.

### Critérios de aceite

- conversão não cria projeto duplicado;
- item convertido aponta para o projeto criado;
- links são validados e podem ser arquivados;
- não há upload ou integrações externas.

Commit sugerido: `feat: add project inbox and related links`

## Fase 5 — Dashboard

### Escopo

- cards de indicadores;
- projetos que precisam de atenção;
- classificação de 15, 30 e 60 dias sem atualização;
- últimos commits;
- filtros contextuais básicos.

### Critérios de aceite

- contagens respeitam RLS;
- datas vencidas e inatividade usam timezone definido;
- indicadores possuem estados vazios e links para a lista filtrada.

Commit sugerido: `feat: add workspace dashboard`

## Fase 6 — Refinamento

### Escopo

- revisão responsiva e de acessibilidade;
- testes de fluxos críticos e policies;
- estados de erro/carregamento;
- revisão de índices e consultas;
- documentação de deploy futuro em VPS;
- avaliação seletiva de Realtime.

### Critérios de aceite

- fluxos principais funcionam em desktop e mobile;
- policies possuem testes positivos e negativos;
- nenhuma chave sensível aparece no bundle ou Git;
- checklist de backup, HTTPS, observabilidade e rollback está documentado antes de produção.

Commit sugerido: `chore: harden CT Workspace MVP`

## Fase futura — Desenvolvimento / GitHub

Esta fase é posterior à fundação e não altera o escopo das Fases 0.5 ou 1. O GitHub será a fonte oficial do código versionado; não haverá leitura do estado interno do Codex.

### Etapas previstas

1. Cadastro de projetos técnicos.
2. Tela Desenvolvimento.
3. Vínculo opcional com projetos estratégicos.
4. Integração autenticada com GitHub.
5. Commits.
6. Branches.
7. Pull Requests.
8. Issues.
9. Deploy.
10. Relação Git Commit ↔ Workspace Commit.
11. Agente local opcional.

### Listagem futura

Projeto, status, projeto estratégico relacionado, repositório, branch principal, último commit, última atividade e ambiente.

### Página técnica futura

Visão geral, Repositório, Commits, Branches, Pull Requests, Issues, Deploy, Projeto relacionado e Histórico.

### Limites

- nenhuma integração GitHub, Codex, OAuth ou sincronização existe na fundação;
- mudanças locais não commitadas não são acompanhadas;
- CI/CD, deploy automático, agente local e CLI permanecem fora do MVP;
- a modelagem detalhada de Git commits será criada junto da integração real, não antecipadamente.

## Backlog posterior ao MVP

- endpoints autenticados para integrações;
- sugestões de IA sempre sujeitas a confirmação humana;
- autenticação de integrações e idempotência;
- anexos e Drive;
- visualização Kanban;
- permissões mais granulares por empresa/unidade.

Esses itens não devem ampliar silenciosamente o escopo das fases do MVP.
