# 0001. Stack da aplicação

Data: 2026-10-01

Status: Aceito

## Contexto

O Nodal é mantido por uma pessoa no início, com meta de colocar o radar do criador em produção ainda na etapa 1. O produto depende de páginas públicas que precisam aparecer corretamente no LinkedIn, cujo crawler não executa JavaScript. As regras de acesso são o ponto mais sensível: conteúdo privado nunca pode vazar para terceiros, nem por comparação ou agregação.

## Decisão

- **Next.js com App Router e TypeScript, hospedado na Vercel.** Páginas de item e perfil são renderizadas no servidor, com meta tags Open Graph e imagem de prévia gerada dinamicamente.
- **Supabase como backend.** Postgres é a fonte única de dados. Auth usa o provedor LinkedIn (OIDC). A API é o PostgREST, e as regras de acesso ficam em Row Level Security, no próprio banco. Edge Functions cobrem o que não cabe no banco.
- **@supabase/ssr** para a sessão no Next.js, via cookies.
- **D3.js** para o radar, num componente client adaptado do Build Your Own Radar (ver [0002](0002-licenca-agpl-e-byor.md)).
- **Resend** para email, disparado por Edge Function a partir de webhook do banco.
- **pg_cron** para tarefas agendadas no banco, como o radar da comunidade.
- **GitHub Actions** para lint, testes, build e migrations. A Vercel gera preview por PR e publica produção a partir da `main`.
- **Testes:** pgTAP ou testes de integração para RLS, testes unitários e Playwright para fluxos end to end.
- **pnpm** como gerenciador de pacotes, fixado no campo `packageManager` do `package.json`.

## Consequências

- Autorização centralizada no banco: toda política precisa de teste automatizado, e o pipeline falha se uma política regredir.
- Pouca infraestrutura própria para operar. Em troca, o projeto depende dos limites dos planos gratuitos da Vercel e do Supabase, que precisam ser monitorados.
- Mudanças de banco só por migration versionada em `supabase/migrations`.
- A chave de service role fica restrita a servidor, CI e Edge Functions.
