# 0002. Licença AGPL 3.0 e atribuição ao BYOR

Data: 2026-10-01

Status: Aceito

## Contexto

A visualização do radar será adaptada do [Build Your Own Radar](https://github.com/thoughtworks/build-your-own-radar) (BYOR), da Thoughtworks, distribuído sob AGPL 3.0. Código derivado de um projeto AGPL precisa ser distribuído sob a mesma licença, e a AGPL estende essa obrigação a software oferecido como serviço pela rede. O projeto também quer ser aberto a contribuições desde o início.

## Decisão

- O repositório é público e todo o código é licenciado sob AGPL 3.0 (`AGPL-3.0-only`), com o texto completo em `LICENSE`.
- Do BYOR aproveitamos apenas a lógica de desenho do radar. A leitura de planilhas e o restante da aplicação original não são usados; os dados vêm da API.
- Cada arquivo derivado do BYOR traz no cabeçalho a origem, o aviso de copyright da Thoughtworks e a referência à AGPL 3.0, além de indicar que foi modificado.
- O README mantém uma seção de atribuição ao BYOR.

## Consequências

- Qualquer pessoa pode estudar, modificar e hospedar o Nodal, desde que publique o código das suas modificações.
- Contribuições externas entram sob a mesma licença, conforme o CONTRIBUTING.
- Dependências novas precisam ter licença compatível com a AGPL 3.0.
- A instância hospedada precisa oferecer acesso ao código fonte, o que já é atendido pelo repositório público.
