# Backlog do Nodal

30 de set. de 2026 · @Rafael

## Visão geral

O produto é uma plataforma aberta onde cada pessoa mantém um radar pessoal de estudos e compara com outros radares, sem que um interfira no outro. O desenvolvimento acontece em três etapas e o lançamento é único, ao fim da etapa 3, com todas as features.

**Estrutura do backlog.** Etapa, Épico, Feature e Item de trabalho. Épicos são numerados por etapa (E1.1 é o primeiro épico da etapa 1), features seguem o épico (F1.1.2) e itens seguem a feature (1.1.2.3). Cada item traz um critério de aceite verificável.

**Stack.** Next.js na Vercel, radar em D3 derivado do BYOR, Supabase (Postgres, Auth com LinkedIn OIDC, API REST via PostgREST, RLS, Edge Functions), Resend para email, GitHub Actions para CI, Playwright para testes end to end. Repositório público sob AGPL 3.0.

**Régua dos anéis.**

| Anel        | Critério                           |
| ----------- | ---------------------------------- |
| Avalie      | Estudei e parece relevante         |
| Experimente | Testei na prática                  |
| Adote       | Usei em projeto real               |
| Evite       | Encontrei motivos concretos contra |

**Definição de pronto geral.** Código no repositório com pipeline verde, migrations versionadas, políticas RLS cobertas por teste, fluxo principal validado manualmente em desktop e mobile, e documentação atualizada quando o item muda um contrato de dados ou de API.

## Etapa 1: Fundação e radar individual

Ao fim da etapa, você publica um estudo no seu radar, compartilha o link no LinkedIn e a prévia aparece correta. O modelo de dados já nasce multiusuário e completo, inclusive as tabelas de interação usadas nas etapas seguintes.

### E1.1 Infraestrutura do projeto

#### F1.1.1 Repositório e governança

| ID      | Item                                                                                        | Critério de aceite                                                        |
| ------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 1.1.1.1 | Criar repositório público com licença AGPL 3.0, README e CONTRIBUTING                       | LICENSE presente; README descreve objetivo, stack e como rodar localmente |
| 1.1.1.2 | Definir padrões de código: lint, formatação, commits convencionais, templates de issue e PR | PR que viola lint falha no CI; templates aparecem ao abrir issue e PR     |
| 1.1.1.3 | Registrar atribuição ao BYOR e decisões de arquitetura em ADRs                              | Pasta docs/adr com ADRs de stack, licença e modelo multiusuário           |

#### F1.1.2 Ambientes e CI

| ID      | Item                                                                                                      | Critério de aceite                                                      |
| ------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 1.1.2.1 | Criar projetos Supabase de desenvolvimento e produção                                                     | Chaves apenas em secrets do GitHub e da Vercel; nenhuma chave no código |
| 1.1.2.2 | Configurar Supabase CLI com migrations versionadas e banco local                                          | Banco local sobe com um comando; migrations aplicam do zero sem erro    |
| 1.1.2.3 | Pipeline no GitHub Actions com lint, testes e build                                                       | Roda em todo PR; merge bloqueado com pipeline vermelho                  |
| 1.1.2.4 | Deploy automático: preview por PR na Vercel, produção na branch principal, migrations aplicadas no deploy | PR gera URL de preview; merge aplica migrations e publica produção      |

### E1.2 Modelo de dados e segurança

#### F1.2.1 Schema multiusuário

| ID      | Item                                                                                                                               | Critério de aceite                                                     |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1.2.1.1 | Tabela de perfis ligada ao usuário autenticado: nome, foto, headline, slug público                                                 | Perfil criado por trigger no primeiro login                            |
| 1.2.1.2 | Catálogo de temas com descrição e apelidos, sem quadrante fixo                                                                     | Nome normalizado único; apelido resolve para o tema canônico           |
| 1.2.1.3 | Itens do radar: usuário, tema, quadrante, anel, resumo, justificativa, link do post, datas, visibilidade                           | Restrição única de um item por usuário por tema                        |
| 1.2.1.4 | Fontes do item: título, URL, tipo                                                                                                  | Item aceita várias fontes; URL validada                                |
| 1.2.1.5 | Histórico de movimentações: anel anterior, novo anel, motivo, autor, data                                                          | Toda mudança de anel gera registro por trigger                         |
| 1.2.1.6 | Tabelas de interação: comentários, votos de anel, referências, propostas de movimentação, seguidores, sugestões de tema, denúncias | Migrations aplicadas, ainda sem telas                                  |
| 1.2.1.7 | Papel de admin da plataforma                                                                                                       | Papel atribuído só por migration ou painel do Supabase, nunca pela API |

#### F1.2.2 Políticas RLS

| ID      | Item                                                                     | Critério de aceite                                            |
| ------- | ------------------------------------------------------------------------ | ------------------------------------------------------------- |
| 1.2.2.1 | Leitura pública de radares públicos, perfis e catálogo                   | Visitante anônimo lê pela API; radar privado não aparece      |
| 1.2.2.2 | Escrita apenas pelo dono em itens, fontes e perfil                       | Usuário B recebe erro ao alterar item de A, coberto por teste |
| 1.2.2.3 | Criação de tema por usuário autenticado; edição do catálogo só por admin | Teste cobre visitante, usuário e admin                        |
| 1.2.2.4 | Suíte de testes de RLS no CI (pgTAP ou integração)                       | Pipeline falha se uma política regredir                       |

### E1.3 Autenticação

#### F1.3.1 Login com LinkedIn

| ID      | Item                                                                              | Critério de aceite                                       |
| ------- | --------------------------------------------------------------------------------- | -------------------------------------------------------- |
| 1.3.1.1 | Configurar app no LinkedIn Developers com OpenID Connect e o provedor no Supabase | Login funciona em dev e produção com callbacks corretos  |
| 1.3.1.2 | Login e logout no Next.js com sessão via cookies (@supabase/ssr)                  | Sessão persiste em páginas SSR; logout invalida a sessão |
| 1.3.1.3 | Onboarding: escolha de slug público e aceite dos termos                           | Sem slug e aceite, o usuário não publica itens           |

### E1.4 Radar individual

#### F1.4.1 Gestão de itens

| ID      | Item                                                              | Critério de aceite                                                                  |
| ------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1.4.1.1 | Formulário de novo item com busca no catálogo antes de criar tema | Temas e apelidos aparecem ao digitar; tema novo exige confirmar que não é duplicado |
| 1.4.1.2 | Edição de item e mudança de anel com motivo obrigatório           | Mudança sem motivo é bloqueada; histórico registra                                  |
| 1.4.1.3 | Gestão de fontes do item                                          | Adicionar, editar e remover fontes                                                  |
| 1.4.1.4 | Rascunho e publicação                                             | Rascunho invisível para outros usuários                                             |

#### F1.4.2 Visualização do radar

| ID      | Item                                                                                       | Critério de aceite                                             |
| ------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| 1.4.2.1 | Extrair e adaptar a renderização D3 do BYOR como componente client                         | Radar desenha quadrantes e anéis a partir da API, sem planilha |
| 1.4.2.2 | Blips clicáveis levando ao detalhe do item                                                 | Clique abre a página do item                                   |
| 1.4.2.3 | Layout responsivo com tema claro e escuro                                                  | Legível a partir de 375px de largura nos dois temas            |
| 1.4.2.4 | Filtros por quadrante, anel e período; itens sem revisão há muito tempo ocultos por padrão | Filtros refletidos na URL                                      |
| 1.4.2.5 | Visão em lista acessível como alternativa ao radar                                         | Leitor de tela percorre todos os itens                         |

#### F1.4.3 Página do item e perfil

| ID      | Item                                                                   | Critério de aceite                                     |
| ------- | ---------------------------------------------------------------------- | ------------------------------------------------------ |
| 1.4.3.1 | Página SSR com resumo, justificativa, fontes, link do post e histórico | Conteúdo presente no HTML sem executar JavaScript      |
| 1.4.3.2 | Meta tags Open Graph e imagem dinâmica com título, quadrante e anel    | Post Inspector do LinkedIn mostra a prévia correta     |
| 1.4.3.3 | Página pública do perfil com o radar do usuário                        | URL por slug; radar privado retorna 404 para terceiros |

**Critério de saída da etapa:** seu radar em produção com pelo menos 10 itens publicados e links compartilhados no LinkedIn com prévia correta.

## Etapa 2: Interação

Ao fim da etapa, um segundo usuário comenta, vota e propõe mudanças no seu radar, e você responde tudo pela plataforma. Nada altera um radar sem o aceite do dono.

### E2.1 Participação nos radares

#### F2.1.1 Comentários

| ID      | Item                                                       | Critério de aceite                                      |
| ------- | ---------------------------------------------------------- | ------------------------------------------------------- |
| 2.1.1.1 | Comentar em item de outro usuário, com respostas em thread | Só autenticado comenta; exibe nome e foto do LinkedIn   |
| 2.1.1.2 | Editar e excluir o próprio comentário                      | Edição marcada como editada; exclusão remove o conteúdo |
| 2.1.1.3 | Dono do radar oculta comentários no próprio item           | Comentário oculto some para terceiros; autor vê aviso   |

#### F2.1.2 Votos de anel

| ID      | Item                                               | Critério de aceite                                                    |
| ------- | -------------------------------------------------- | --------------------------------------------------------------------- |
| 2.1.2.1 | Votar no anel que o item deveria ocupar            | Um voto por usuário por item, trocável; dono não vota no próprio item |
| 2.1.2.2 | View agregada com a distribuição de votos por item | API retorna a contagem por anel e quem votou em cada anel             |
| 2.1.2.3 | Exibir a distribuição ao lado do anel do dono      | Item recebe indicador visual quando a maioria diverge do dono         |

#### F2.1.3 Referências sugeridas

| ID      | Item                                            | Critério de aceite                                   |
| ------- | ----------------------------------------------- | ---------------------------------------------------- |
| 2.1.3.1 | Sugerir referência com URL, título e comentário | Fica pendente até o dono decidir                     |
| 2.1.3.2 | Dono aceita ou recusa a referência              | Aceita vira fonte do item com crédito a quem sugeriu |

#### F2.1.4 Propostas de movimentação

| ID      | Item                                                                      | Critério de aceite                                                             |
| ------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 2.1.4.1 | Criar proposta com anel sugerido, justificativa e ao menos uma referência | Proposta sem referência é bloqueada                                            |
| 2.1.4.2 | Dono aceita ou rejeita com resposta obrigatória                           | Aceite move o item e grava no histórico com crédito; rejeição exibe a resposta |
| 2.1.4.3 | Limite de propostas abertas                                               | No máximo uma proposta aberta por usuário por item                             |

### E2.2 Rede

#### F2.2.1 Seguidores e feed

| ID      | Item                                                       | Critério de aceite                          |
| ------- | ---------------------------------------------------------- | ------------------------------------------- |
| 2.2.1.1 | Seguir e deixar de seguir usuários                         | Contagem de seguidores e seguidos no perfil |
| 2.2.1.2 | Feed com novos itens e mudanças de anel de quem você segue | Feed paginado em ordem cronológica          |

### E2.3 Notificações

#### F2.3.1 Notificações na plataforma

| ID      | Item                                              | Critério de aceite                                                 |
| ------- | ------------------------------------------------- | ------------------------------------------------------------------ |
| 2.3.1.1 | Central de notificações com contador de não lidas | Comentário, proposta, referência e novo seguidor geram notificação |
| 2.3.1.2 | Marcar como lida, individualmente ou todas        | Contador atualiza na hora                                          |

#### F2.3.2 Email

| ID      | Item                                                          | Critério de aceite                                                 |
| ------- | ------------------------------------------------------------- | ------------------------------------------------------------------ |
| 2.3.2.1 | Webhook do banco chamando Edge Function que envia pelo Resend | Proposta e referência recebidas geram email em até 5 minutos       |
| 2.3.2.2 | Preferências por tipo de notificação e resumo diário opcional | Usuário desliga email por tipo; todo email tem link de descadastro |
| 2.3.2.3 | Domínio de envio com SPF, DKIM e DMARC                        | Emails de teste chegam na caixa de entrada do Gmail e do Outlook   |

### E2.4 Moderação e proteção

#### F2.4.1 Moderação

| ID      | Item                                            | Critério de aceite                                                |
| ------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| 2.4.1.1 | Denunciar comentário, item ou perfil com motivo | Denúncia entra na fila do admin                                   |
| 2.4.1.2 | Painel de moderação do admin                    | Admin oculta conteúdo e suspende conta; toda ação fica em log     |
| 2.4.1.3 | Bloquear usuário                                | Bloqueado não comenta, vota nem propõe nos itens de quem bloqueou |

#### F2.4.2 Proteção contra abuso

| ID      | Item                                                            | Critério de aceite                                           |
| ------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| 2.4.2.1 | Limitação de taxa por usuário em comentários, votos e propostas | Acima do limite retorna erro 429 com mensagem clara          |
| 2.4.2.2 | Sanitização de conteúdo e links                                 | HTML e scripts não executam; links externos com rel nofollow |

**Critério de saída da etapa:** um usuário de teste comenta, vota, sugere referência e propõe mudança no seu radar; você recebe notificação e email, responde, e o histórico mostra o crédito. Testes de RLS cobrem todas as tabelas de interação.

## Etapa 3: Camada social e lançamento

Ao fim da etapa, comparação, radar da comunidade e sugestões funcionam com dados reais de um beta fechado, e o cadastro abre ao público. É a menor etapa em código, mas a mais longa em calendário por causa do beta.

### E3.1 Comparação e comunidade

#### F3.1.1 Comparação entre radares

| ID      | Item                                                                                                              | Critério de aceite                                                           |
| ------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| 3.1.1.1 | Tela de comparação entre dois radares: temas em comum, divergências de quadrante e de anel, exclusivos de cada um | Acessível a partir de qualquer perfil público; só considera radares públicos |
| 3.1.1.2 | Índice de similaridade entre radares por sobreposição de temas e anéis                                            | Cálculo documentado e exibido na comparação                                  |
| 3.1.1.3 | Página do tema com o anel de cada usuário que o possui                                                            | Lista radares públicos e a distribuição por quadrante e anel                 |

#### F3.1.2 Radar da comunidade

| ID      | Item                                                                                                                    | Critério de aceite                                                               |
| ------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 3.1.2.1 | View materializada agregando quadrante e anel por tema (o mais frequente de cada), atualizada por agendamento (pg_cron) | Atualização periódica sem impacto perceptível nas páginas                        |
| 3.1.2.2 | Página do radar da comunidade com consenso e maiores divergências                                                       | Temas ranqueados pela proporção de radares que os possuem, sem corte mínimo fixo |

#### F3.1.3 Sugestões de temas

| ID      | Item                                                                               | Critério de aceite                        |
| ------- | ---------------------------------------------------------------------------------- | ----------------------------------------- |
| 3.1.3.1 | Sugestões por regras: temas populares entre quem você segue e em radares similares | Exclui temas que você já tem ou dispensou |
| 3.1.3.2 | Sugerir um tema diretamente para outro usuário                                     | Dono aceita (vira rascunho) ou dispensa   |
| 3.1.3.3 | Dispensar sugestão                                                                 | Sugestão dispensada não volta a aparecer  |

### E3.2 Privacidade e conformidade

#### F3.2.1 Privacidade e LGPD

| ID      | Item                                                       | Critério de aceite                                                                                            |
| ------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 3.2.1.1 | Radar público ou privado e itens individuais privados      | Conteúdo privado fica fora de comparação, comunidade e sugestões                                              |
| 3.2.1.2 | Termos de uso e política de privacidade publicados         | Aceite registrado com data e versão do texto                                                                  |
| 3.2.1.3 | Exportação dos dados do usuário                            | Arquivo JSON com perfil, itens e interações                                                                   |
| 3.2.1.4 | Exclusão de conta                                          | Antes de excluir, o usuário escolhe anonimizar ou remover suas contribuições; dados pessoais sempre removidos |
| 3.2.1.5 | Métricas de uso com ferramenta sem cookies de rastreamento | Nenhum cookie de terceiros carregado nas páginas                                                              |

### E3.3 Qualidade e operação

#### F3.3.1 Testes, observabilidade e backup

| ID      | Item                                                                                            | Critério de aceite                              |
| ------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| 3.3.1.1 | Testes end to end com Playwright: login, criar item, comentar, votar, propor, aceitar, comparar | Rodam no CI contra o preview de cada PR         |
| 3.3.1.2 | Monitoramento de erros com alertas                                                              | Erro em produção gera alerta com stack trace    |
| 3.3.1.3 | Export noturno dos itens públicos para JSON versionado no repositório                           | Job diário gera commit quando há mudanças       |
| 3.3.1.4 | Revisão de performance e índices do banco                                                       | Páginas principais com p95 abaixo de 2 segundos |
| 3.3.1.5 | Revisão de acessibilidade                                                                       | Fluxos principais navegáveis por teclado        |

### E3.4 Beta fechado e lançamento

#### F3.4.1 Beta fechado

| ID      | Item                                              | Critério de aceite                                  |
| ------- | ------------------------------------------------- | --------------------------------------------------- |
| 3.4.1.1 | Convites para 10 a 20 pessoas com lista de acesso | Cadastro fora da lista bloqueado durante o beta     |
| 3.4.1.2 | Canal de feedback com triagem                     | Feedback relevante vira issue no GitHub             |
| 3.4.1.3 | Ferramenta de admin para mesclar temas duplicados | Merge preserva itens, votos e histórico             |
| 3.4.1.4 | Beta de 2 a 3 semanas com meta de participação    | Cada participante com pelo menos 5 itens publicados |

#### F3.4.2 Lançamento

| ID      | Item                                                                                    | Critério de aceite                                         |
| ------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 3.4.2.1 | Página inicial explicando o produto, a régua dos anéis e como contribuir no repositório | Publicada e revisada                                       |
| 3.4.2.2 | Abertura do cadastro                                                                    | Lista de acesso desativada                                 |
| 3.4.2.3 | Posts de lançamento usando divergências reais do beta                                   | Pelo menos 3 posts programados para a semana de lançamento |

**Critério de saída da etapa:** comparação e radar da comunidade exibindo dados do beta, testes end to end verdes, textos legais publicados e cadastro aberto.

## Dependências, riscos e decisões em aberto

O schema multiusuário (F1.2.1) e as políticas RLS (F1.2.2) bloqueiam todo o resto, por isso vêm primeiro. O login (F1.3.1) bloqueia a etapa 2 inteira. Votos (F2.1.2) e seguidores (F2.2.1) alimentam o radar da comunidade e as sugestões da etapa 3. O beta só começa com a moderação (E2.4) pronta.

### Riscos

| Risco                                                           | Impacto                                      | Mitigação                                                                   |
| --------------------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- |
| Temas duplicados no catálogo                                    | Comparação e radar da comunidade distorcidos | Busca antes de criar, apelidos e merge pelo admin (3.4.1.3)                 |
| Baixa adesão no beta                                            | Features sociais vazias no lançamento        | Convidar acima da meta, meta de itens por participante, seu radar como base |
| Desenvolvimento competindo com a cadência de 3 posts por semana | Atraso no projeto ou queda nas publicações   | Etapa 1 prioriza seu uso real; os estudos alimentam o radar desde cedo      |
| Mudança ou restrição no app do LinkedIn                         | Login indisponível                           | Avaliar login por link mágico no email como alternativa                     |
| Spam após a abertura                                            | Moderação manual sobrecarregada              | Limitação de taxa, bloqueio e denúncias já no lançamento                    |
| Limites do plano gratuito do Supabase                           | Instabilidade com o crescimento              | Monitorar uso e prever plano pago a partir do lançamento                    |

### Decisões tomadas

| Decisão                           | Resultado                                                                |
| --------------------------------- | ------------------------------------------------------------------------ |
| Quadrante                         | Pertence ao item de cada usuário; o catálogo de temas não fixa quadrante |
| Votos de anel                     | Visíveis individualmente                                                 |
| Presença no radar da comunidade   | Ranking relativo pela proporção de radares, sem número mínimo fixo       |
| Contribuições de contas excluídas | O usuário escolhe anonimizar ou remover antes da exclusão                |
| Idioma da interface               | Português do Brasil, com estrutura de i18n pronta para inglês            |
| Gerenciador de pacotes            | pnpm                                                                     |

### Decisões em aberto

- [ ] Prazo sem revisão para um item sair da visualização padrão
- [ ] Login alternativo além do LinkedIn
- [ ] Nome definitivo e domínio: Nodal adotado como nome provisório, decisão final antes do beta
