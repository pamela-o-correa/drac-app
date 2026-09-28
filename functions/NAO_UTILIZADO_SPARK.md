# Somente ferramentas de teste

O aplicativo não usa Cloud Functions. Esta pasta não está em firebase.json. package.json contém apenas dependências de desenvolvimento para executar os testes de Security Rules no emulador.

O servidor anterior e seus testes foram arquivados em legacy/ e não são executados pelos testes atuais nem publicados. Não habilite Blaze. Rode pnpm test para testar a implementação Spark; não publique funções.
