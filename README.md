# Nodal

Nodal é uma plataforma aberta onde cada pessoa mantém um radar pessoal de estudos de tecnologia e compara com os radares de outras pessoas. A ideia vem do [Technology Radar](https://www.thoughtworks.com/radar) da Thoughtworks.

> Nodal é um nome provisório. O projeto está em desenvolvimento e ainda não tem versão pública.

## Como funciona

Você estuda um tema (tecnologia, ferramenta, técnica ou conceito), registra as fontes, escreve um resumo e posiciona o tema no seu radar, em um quadrante e um anel. Cada item tem uma página própria com resumo, justificativa, fontes, histórico de movimentações e o link do post publicado no LinkedIn sobre aquele estudo.

Quadrantes: Técnicas, Ferramentas, Plataformas, Linguagens e Frameworks.

| Anel        | Critério                           |
| ----------- | ---------------------------------- |
| Adote       | Usei em projeto real               |
| Experimente | Testei na prática                  |
| Avalie      | Estudei e parece relevante         |
| Evite       | Encontrei motivos concretos contra |

Outras pessoas autenticadas podem comentar, votar no anel que acham correto, sugerir referências e propor mudanças de anel. Nada altera um radar sem o aceite do dono. A plataforma também compara radares, agrega um radar da comunidade e sugere temas.

## Stack

- **Front end:** Next.js (App Router) com TypeScript, hospedado na Vercel. Páginas de item e perfil renderizadas no servidor com Open Graph.
- **Radar:** componente em D3.js adaptado do [Build Your Own Radar](https://github.com/thoughtworks/build-your-own-radar).
- **Backend:** Supabase (Postgres, Auth com LinkedIn OIDC, PostgREST, Row Level Security, Edge Functions).
- **Email:** Resend.
- **CI e CD:** GitHub Actions e Vercel.
- **Testes:** testes de RLS, testes unitários e Playwright.

As decisões de arquitetura estão em [docs/adr](docs/adr) e o backlog em [docs/backlog.md](docs/backlog.md).

## Como rodar localmente

Requisitos:

- Node.js LTS (24 ou superior)
- pnpm 10 ou superior
- Docker, para o Supabase local (a Supabase CLI vem como dependência do projeto)
- git

Passos:

```bash
git clone https://github.com/RafaGiaretta/nodal.git
cd nodal
pnpm install
cp .env.example .env.local   # preencha com as chaves do Supabase local
pnpm db:start                # sobe o Supabase local e aplica as migrations
pnpm dev                     # abre em http://localhost:3000
```

`pnpm db:start` mostra a URL e as chaves locais para preencher o `.env.local`. O Studio fica em http://127.0.0.1:54323.

Outros comandos:

| Comando             | O que faz                                                                |
| ------------------- | ------------------------------------------------------------------------ |
| `pnpm db:reset`     | Recria o banco local do zero, aplicando migrations e `supabase/seed.sql` |
| `pnpm db:status`    | Mostra URLs e chaves do ambiente local                                   |
| `pnpm db:stop`      | Para os containers do Supabase                                           |
| `pnpm lint`         | ESLint, sem tolerar avisos                                               |
| `pnpm typecheck`    | Gera os tipos de rota do Next.js e roda o TypeScript                     |
| `pnpm test`         | Testes unitários (Vitest)                                                |
| `pnpm test:db`      | Testes pgTAP do banco, inclusive RLS (exige `pnpm db:start`)             |
| `pnpm format:check` | Confere a formatação com Prettier                                        |
| `pnpm build`        | Build de produção                                                        |

## Como contribuir

Leia o [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença e atribuição

Distribuído sob a [GNU Affero General Public License 3.0](LICENSE).

A visualização do radar deriva do [Build Your Own Radar](https://github.com/thoughtworks/build-your-own-radar), da Thoughtworks, também sob AGPL 3.0. Os arquivos derivados dele trazem essa atribuição no cabeçalho.
