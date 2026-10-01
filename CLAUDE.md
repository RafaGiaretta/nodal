# Nodal

Contexto do projeto para o Claude Code. Este arquivo fica na raiz do repositório e é lido automaticamente no início de cada sessão. Mantenha atualizado sempre que uma decisão mudar.

## O que é o produto

Nodal é uma plataforma aberta onde cada pessoa mantém um radar pessoal de estudos de tecnologia, inspirado no Technology Radar da Thoughtworks, e compara com os radares de outras pessoas.

O fluxo de uso: a pessoa estuda um tema (tecnologia, ferramenta, técnica, conceito), documenta as fontes, escreve um resumo e posiciona o tema no próprio radar, em um quadrante e um anel. Cada item tem uma página própria com resumo, justificativa, fontes, histórico de movimentações e o link do post publicado no LinkedIn sobre aquele estudo.

A camada social permite que usuários autenticados comentem, votem no anel que acham correto, sugiram referências e proponham mudanças de anel nos radares de outros. Nada altera um radar sem o aceite do dono. A plataforma também compara radares entre si, agrega um radar da comunidade e sugere temas.

O criador (Rafael) usa o próprio radar como base de conteúdo para o LinkedIn, com meta de 3 posts por semana. O radar dele é o primeiro a ser alimentado, já durante o desenvolvimento.

"Nodal" é um nome provisório. A decisão final acontece antes do beta.

## Quadrantes e anéis

Quadrantes: Técnicas, Ferramentas, Plataformas, Linguagens e Frameworks.

Anéis e a régua usada para posicionar cada item:

| Anel        | Valor no banco | Critério                           |
| ----------- | -------------- | ---------------------------------- |
| Adote       | adopt          | Usei em projeto real               |
| Experimente | trial          | Testei na prática                  |
| Avalie      | assess         | Estudei e parece relevante         |
| Evite       | hold           | Encontrei motivos concretos contra |

O quadrante pertence ao item de cada usuário, não ao tema. Dois usuários podem classificar o mesmo tema em quadrantes diferentes, e a comparação mostra essa divergência.

## Stack

- Front end: Next.js (App Router) com TypeScript, hospedado na Vercel. Páginas de item e perfil renderizadas no servidor, com meta tags Open Graph e imagem de prévia dinâmica, porque o crawler do LinkedIn não executa JavaScript.
- Visualização do radar: componente client em D3.js, adaptado do Build Your Own Radar (BYOR) da Thoughtworks. Aproveitar apenas a lógica de desenho; os dados vêm da API, não de planilha.
- Backend: Supabase. Postgres como fonte única de dados, Auth com o provedor LinkedIn (OIDC), API REST via PostgREST, regras de acesso via Row Level Security, Edge Functions para o que não cabe no banco.
- Sessão no Next.js: pacote @supabase/ssr com cookies.
- Email: Resend, disparado por Edge Function a partir de webhook do banco.
- CI e CD: GitHub Actions para lint, testes, build e migrations. Preview por PR e produção na branch principal pela Vercel.
- Testes: testes de RLS (pgTAP ou integração), testes unitários, e testes end to end com Playwright.
- Agendamentos no banco: pg_cron (radar da comunidade).

## Licença e repositório

Repositório público sob AGPL 3.0, licença herdada do BYOR. Manter atribuição ao BYOR no README e nos arquivos derivados dele. Registrar decisões de arquitetura em docs/adr.

## Modelo de dados

O schema nasce multiusuário e completo desde a primeira migration, incluindo as tabelas de interação usadas apenas nas etapas 2 e 3. Nomes de tabelas e colunas em inglês, snake_case. Proposta inicial, ajustável durante a implementação:

| Tabela                   | Conteúdo principal                                                                                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| profiles                 | id (igual a auth.users.id), slug único, display_name, avatar_url, headline, role (user ou admin), terms_version, terms_accepted_at, radar_visibility                                                   |
| topics                   | id, name, normalized_name único, description, created_by                                                                                                                                               |
| topic_aliases            | id, topic_id, alias, normalized_alias único                                                                                                                                                            |
| radar_items              | id, user_id, topic_id, quadrant, ring, summary, rationale, linkedin_post_url, status (draft ou published), visibility (public ou private), studied_at, last_reviewed_at; único por (user_id, topic_id) |
| item_sources             | id, item_id, title, url, kind, suggested_by (opcional, crédito de referência aceita)                                                                                                                   |
| ring_history             | id, item_id, from_quadrant, to_quadrant, from_ring, to_ring, reason, changed_by, proposal_id (opcional), created_at                                                                                    |
| comments                 | id, item_id, author_id, parent_id, body, status (visible, hidden, removed), edited_at                                                                                                                  |
| ring_votes               | item_id, voter_id, ring; chave primária (item_id, voter_id); votos visíveis individualmente                                                                                                            |
| reference_suggestions    | id, item_id, author_id, url, title, note, status (pending, accepted, rejected)                                                                                                                         |
| move_proposals           | id, item_id, author_id, proposed_ring, rationale, status, owner_response, resolved_at                                                                                                                  |
| move_proposal_references | id, proposal_id, url, title                                                                                                                                                                            |
| follows                  | follower_id, followee_id                                                                                                                                                                               |
| topic_suggestions        | id, from_user, to_user, topic_id, note, status (pending, accepted, dismissed)                                                                                                                          |
| reports                  | id, reporter_id, target_type, target_id, reason, status                                                                                                                                                |
| user_blocks              | blocker_id, blocked_id                                                                                                                                                                                 |
| notifications            | id, user_id, type, payload (jsonb), read_at                                                                                                                                                            |
| notification_preferences | user_id, type, email_enabled, digest                                                                                                                                                                   |

Triggers previstas:

- Criar profile no primeiro login.
- Gravar ring_history em toda mudança de anel ou quadrante de um item (motivo obrigatório).
- Normalizar name e alias para impedir temas duplicados.

## Regras de acesso (RLS)

- Leitura pública de perfis, catálogo de temas e itens publicados de radares públicos.
- Conteúdo privado (radar ou item) nunca aparece para terceiros, nem em comparação, radar da comunidade ou sugestões.
- Escrita em itens, fontes e perfil apenas pelo dono.
- Qualquer usuário autenticado cria tema; edição e merge do catálogo apenas por admin.
- Comentários, votos, referências e propostas: o autor cria e edita os próprios; o dono do item decide sobre referências e propostas e pode ocultar comentários no próprio item.
- Dono não vota no próprio item. No máximo uma proposta aberta por usuário por item.
- Usuário bloqueado não comenta, vota nem propõe nos itens de quem bloqueou.
- O papel de admin nunca é atribuído pela API, apenas por migration ou painel do Supabase.
- Toda política nova precisa de teste automatizado. O pipeline falha se uma política regredir.

## Decisões tomadas

| Tema                   | Decisão                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| Formato                | Plataforma multiusuário desde o primeiro dia, com lançamento único contendo todas as features              |
| Quadrante              | Pertence ao item de cada usuário                                                                           |
| Votos de anel          | Visíveis individualmente                                                                                   |
| Radar da comunidade    | Ranking relativo pela proporção de radares que têm o tema, sem número mínimo fixo                          |
| Exclusão de conta      | O usuário escolhe anonimizar ou remover as contribuições antes de excluir; dados pessoais sempre removidos |
| Nome                   | Nodal, provisório                                                                                          |
| Idioma da interface    | Português do Brasil, com estrutura de i18n pronta para inglês (ADR 0004)                                   |
| Gerenciador de pacotes | pnpm (ADR 0001)                                                                                            |

## Decisões em aberto

- Prazo sem revisão para um item sair da visualização padrão do radar.
- Login alternativo além do LinkedIn (candidato: link mágico por email).
- Nome definitivo e domínio.

## Plano de desenvolvimento

Três etapas de desenvolvimento, lançamento ao fim da terceira. O backlog completo, com épicos, features, itens e critérios de aceite, está em docs/backlog.md. Sempre referencie o ID do item (por exemplo 1.2.1.3) em branches, commits e PRs.

Etapa 1, Fundação e radar individual. Infraestrutura do repositório e CI, schema completo com RLS e testes, login LinkedIn com onboarding, cadastro de itens com busca no catálogo, radar em D3, páginas SSR de item e perfil com Open Graph. Saída: radar do Rafael em produção com pelo menos 10 itens e prévia correta no LinkedIn.

Etapa 2, Interação. Comentários, votos de anel, referências sugeridas, propostas de movimentação, seguidores e feed, notificações na plataforma e por email, moderação, bloqueio, denúncias e limitação de taxa.

Etapa 3, Camada social e lançamento. Comparação entre radares, radar da comunidade, sugestões de temas, privacidade e LGPD, testes end to end, monitoramento, export noturno dos itens públicos para JSON no repositório, beta fechado com 10 a 20 pessoas e abertura do cadastro.

Ordem de dependência: schema e RLS bloqueiam tudo; login bloqueia a etapa 2; votos e seguidores alimentam a etapa 3; o beta só começa com moderação pronta.

## Ambiente e configuração

Requisitos na máquina: Node.js LTS, Docker (para o Supabase local), Supabase CLI, git. GitHub CLI é opcional.

Contas externas que o Rafael configura manualmente: GitHub, Vercel, Supabase (projetos de desenvolvimento e produção), app no LinkedIn Developers com o produto "Sign In with LinkedIn using OpenID Connect", Resend com domínio verificado.

Variáveis de ambiente previstas:

- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY (ou a chave pública equivalente do projeto)
- SUPABASE_SERVICE_ROLE_KEY, somente em servidor, CI e Edge Functions, nunca no client
- RESEND_API_KEY, somente nas Edge Functions

Credenciais do LinkedIn ficam configuradas no painel do Supabase, não no repositório. Manter um .env.example sem valores reais.

## Regras de trabalho para o Claude Code

- Nunca commitar segredos, chaves ou arquivos .env. Se encontrar algum, pare e avise.
- Toda mudança de banco é feita por migration versionada em supabase/migrations, nunca alterando o banco remoto direto.
- Antes de concluir um item, rode lint, testes e build localmente e confira o critério de aceite do backlog.
- Commits no padrão Conventional Commits, em inglês, citando o ID do item do backlog.
- Trabalhe em branch por item ou feature e abra PR; não faça push direto na branch principal.
- Pergunte antes de decisões que não estão registradas aqui ou no backlog, em vez de assumir.
- Ao tomar uma decisão de arquitetura relevante, registre um ADR curto em docs/adr e atualize este arquivo.
- Textos voltados a pessoas (README, documentação, interface, posts) em português, sem hífens nem travessões, diretos e sem floreio.

## Primeira sessão sugerida

1. Ler este arquivo e docs/backlog.md.
2. Confirmar com o Rafael a decisão de idioma da interface e o gerenciador de pacotes.
3. Executar os itens 1.1.1.1 a 1.1.1.3: LICENSE AGPL 3.0, README, CONTRIBUTING, padrões de lint e formatação, templates de issue e PR, primeiros ADRs (stack, licença, modelo multiusuário).
4. Criar o projeto Next.js com TypeScript e inicializar o Supabase CLI (item 1.1.2.2).
5. Configurar o pipeline do GitHub Actions (item 1.1.2.3).
6. Seguir para o schema e as políticas RLS (F1.2.1 e F1.2.2), começando pela migration inicial e pelos testes de RLS.
