# Como contribuir

Obrigado pelo interesse no Nodal. Este guia explica como propor mudanças.

## Antes de começar

- Procure uma issue existente ou abra uma nova descrevendo o problema ou a ideia.
- Itens planejados estão em [docs/backlog.md](docs/backlog.md), cada um com um ID (por exemplo 1.2.1.3) e um critério de aceite.
- Decisões de arquitetura ficam em [docs/adr](docs/adr). Se a sua mudança altera uma delas, proponha um ADR novo.

## Fluxo de trabalho

1. Crie uma branch a partir de `main`, com o tipo e o ID do item no nome: `feat/1.4.1.1-item-form`.
2. Faça commits pequenos no padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/), em inglês, citando o ID do item:

   ```text
   feat(items): add catalog search to item form (1.4.1.1)
   ```

   Tipos aceitos: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

3. Antes de abrir o PR, rode localmente:

   ```bash
   pnpm lint
   pnpm format:check
   pnpm test
   pnpm build
   ```

4. Abra o PR para `main` preenchendo o template. O merge só acontece com o pipeline verde e revisão aprovada.

Nunca faça push direto na `main`.

## Banco de dados

- Toda mudança de schema é feita por migration em `supabase/migrations`. Nunca altere o banco remoto direto.
- Toda política de Row Level Security nova ou alterada precisa de teste automatizado.
- O papel de admin nunca é atribuído pela API.

## Segredos

Nunca commite chaves, tokens ou arquivos `.env`. Use o `.env.example` como modelo, sem valores reais. Se encontrar um segredo no repositório, avise na issue sem expor o valor.

## Textos

Textos voltados a pessoas (interface, documentação, README) são escritos em português do Brasil, de forma direta. A interface usa a estrutura de i18n, então todo texto novo entra nos arquivos de mensagens, não direto no componente.

## Código derivado do BYOR

Arquivos adaptados do [Build Your Own Radar](https://github.com/thoughtworks/build-your-own-radar) mantêm no cabeçalho a atribuição à Thoughtworks e a referência à AGPL 3.0.

## Licença

Ao contribuir, você concorda que a sua contribuição será distribuída sob a [AGPL 3.0](LICENSE).
