# 0005. Schema inicial e regras de acesso no banco

Data: 2026-10-02

Status: Aceito

## Contexto

O schema multiusuário e as políticas de RLS bloqueiam todo o resto do backlog (F1.2.1 e F1.2.2). Algumas regras de negócio precisavam de uma forma concreta no banco: evitar temas duplicados, exigir motivo em toda mudança de anel ou quadrante, impedir que a API atribua o papel de admin e criar as tabelas de interação antes das telas que as usam.

## Decisão

- **Normalização de nomes.** `normalize_name` converte para minúsculas, remove acentos e remove espaços, pontos, hífens e sublinhados, mantendo `#` e `+`. "Next.js", "next js" e "NextJS" viram o mesmo tema; "C", "C#" e "C++" continuam distintos. Nomes de temas e apelidos ficam no mesmo espaço: um apelido não pode coincidir com o nome de outro tema, e vice versa. `resolve_topic` devolve o tema canônico a partir de nome ou apelido.
- **Motivo da movimentação.** `radar_items.move_reason` é uma coluna transitória: o cliente envia o motivo no mesmo PATCH que muda `ring` ou `quadrant`, a trigger exige o motivo, grava em `ring_history` e limpa a coluna, que nunca fica armazenada. A criação do item gera um registro inicial no histórico, sem motivo.
- **Permissões por coluna além do RLS.** O RLS decide quais linhas cada pessoa lê e escreve; os `grant` por coluna decidem quais campos a API pode escrever. Assim `profiles.role`, `profiles.terms_accepted_at`, `radar_items.user_id` e `item_sources.suggested_by` nunca são escritos pela API. A data de aceite dos termos é preenchida pelo servidor quando `terms_version` muda.
- **Publicação exige onboarding.** Um item só passa a `published` se o perfil tem slug e aceite dos termos.
- **Visibilidade.** Terceiros veem um item apenas se ele está publicado, é público e o radar do dono é público. Fontes e histórico seguem a visibilidade do item.
- **Tabelas de interação fechadas.** As tabelas das etapas 2 e 3 nascem com RLS habilitado e sem políticas. Cada política entra na etapa correspondente, junto com o próprio teste.
- **Exclusão de conta.** Votos, seguidores e bloqueios são removidos com a conta. Comentários, referências e propostas ficam sem autor (`on delete set null`), o que permite anonimizar. A opção de remover as contribuições será implementada no item 3.2.1.4.
- **Teste de guarda.** Um teste pgTAP falha se qualquer tabela do schema `public` estiver sem RLS.

## Consequências

- O front envia `move_reason` sempre que mudar anel ou quadrante; sem ele, a API responde com erro de restrição (`23514`).
- Mudar a regra de normalização depois exige migrar `normalized_name` e `normalized_alias` e resolver as colisões que surgirem.
- Uma coluna nova em tabela com permissão por coluna precisa ser incluída no `grant` correspondente, senão a API não consegue escrevê-la.
