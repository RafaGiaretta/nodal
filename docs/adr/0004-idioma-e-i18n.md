# 0004. Interface em português com i18n pronta

Data: 2026-10-01

Status: Aceito

## Contexto

O público inicial é brasileiro e o conteúdo do criador é publicado em português. Ao mesmo tempo, o projeto é aberto e pode atrair pessoas de outros países. Traduzir uma interface com textos espalhados pelo código é trabalhoso; externalizar os textos desde o início custa pouco.

## Decisão

- A interface é lançada em português do Brasil (`pt-BR`).
- Todo texto de interface fica em arquivos de mensagens, e não direto nos componentes, usando a biblioteca [next-intl](https://next-intl.dev), que suporta Server Components do App Router.
- Enquanto houver um único idioma, as URLs não levam prefixo de idioma, para que os links compartilhados no LinkedIn continuem válidos quando o inglês for adicionado.
- Datas e números são formatados pela API de internacionalização, a partir do idioma ativo.
- O conteúdo escrito pelos usuários (resumos, justificativas, comentários) não é traduzido.

## Consequências

- Adicionar inglês exige criar o arquivo de mensagens e definir a estratégia de URL para o novo idioma, sem refatorar componentes.
- Revisões de código conferem que nenhum texto de interface entrou direto no componente.
- A estratégia de URL para mais de um idioma será decidida em um ADR próprio quando o inglês entrar.
