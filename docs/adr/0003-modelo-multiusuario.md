# 0003. Modelo multiusuário desde o primeiro dia

Data: 2026-10-01

Status: Aceito

## Contexto

O primeiro radar alimentado será o do criador, ainda durante o desenvolvimento. Seria possível começar com um radar único e adicionar usuários depois, mas a comparação entre radares, o radar da comunidade e a camada social dependem de um modelo em que cada pessoa tem o próprio radar e o catálogo de temas é compartilhado. Migrar de um modelo de usuário único para multiusuário depois, com dados reais e políticas de acesso já em uso, é caro e arriscado.

## Decisão

- O schema nasce multiusuário e completo na primeira migration, incluindo as tabelas de interação usadas só nas etapas 2 e 3.
- O catálogo de temas (`topics` e `topic_aliases`) é compartilhado. Nomes e apelidos são normalizados para impedir duplicatas.
- Quadrante e anel pertencem ao item de cada usuário (`radar_items`), não ao tema. Dois usuários podem classificar o mesmo tema de formas diferentes, e a comparação mostra essa divergência.
- Existe no máximo um item por usuário por tema.
- Toda mudança de anel ou quadrante gera registro em `ring_history` por trigger, com motivo obrigatório.
- Nada altera o radar de alguém sem o aceite do dono. Interações de terceiros (votos, referências, propostas) ficam em tabelas próprias até a decisão.
- O lançamento é único, ao fim da etapa 3, com todas as features.

## Consequências

- Políticas de RLS precisam existir e ter testes desde a primeira migration, inclusive para tabelas ainda sem tela.
- O radar do criador já roda no mesmo modelo que os demais usuários, sem caminho especial no código.
- O catálogo compartilhado exige busca antes de criar tema e, mais tarde, uma ferramenta de admin para mesclar duplicatas (item 3.4.1.3).
