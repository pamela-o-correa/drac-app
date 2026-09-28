# Arquitetura Spark do Drác App

## Base preservada

O aplicativo Flutter existente usa SQLite (`drac.db`) e mapas Dart para perfil, tratamentos, medicamentos, horários e administrações. As telas e o despertador Android continuam usando o acesso existente ao banco. Não houve recriação do aplicativo nem alteração geral do design.

## Fluxo implementado

Firebase Auth identifica cada cuidador e exige e-mail confirmado. `SparkRepository` executa transações diretamente no Firestore. Security Rules validam vínculo, autoria, versões e gravação conjunta do evento. `SharedService` mantém listeners de configuração, doses e avisos; `SharedDatabase` projeta os snapshots em um SQLite separado por conta/grupo. As telas reagem ao stream de alterações existente.

Não há chamadas HTTP callable, Firebase Admin SDK no aplicativo, Cloud Functions nem FCM obrigatório. A pasta `functions/legacy` conserva o código servidor antigo apenas como arquivo de referência, sem configuração de publicação e sem dependências de execução exigidas pelo app.

## Banco remoto

```text
users/{uid}                         grupo vinculado e nome
groups/{groupId}                    owner, members (até 2), migrationOpen, inviteCode
groups/{groupId}/pets/drac           perfil, tratamentos, medicamentos, horários,
                                   medicationsById, version, nextId, lastEventId
groups/{groupId}/slots/{med_dia_hora} estado atual de um horário, autoria, dose, versão
groups/{groupId}/events/{operationId} histórico imutável, antes/depois, autor e tempos
invites/{codigoAleatorio}           grupo, dono, validade; removido no uso
```

A configuração permanece em um documento com listas para preservar IDs e o modelo SQLite existente, e permitir medicamento+horários+histórico numa única transação. Para duas pessoas e um animal isso reduz complexidade; não é uma arquitetura para milhares de medicamentos. O cliente limita o snapshot de configuração a 200 KB e até 500 registros por lista (perfil único), deixando margem para o evento com antes/depois. Fotos locais continuam locais: não foi adicionado upload de arquivos.

`firestore.indexes.json` não exige índices compostos: os streams usam documento, coleção ou ordenação/filtro pelo mesmo campo `serverAt`. Campos grandes não consultados são dispensados de indexação automática.

## Segurança e conflitos

- Leitura do grupo, perfil, doses e eventos somente por integrantes com e-mail confirmado. Perfil de usuário acessível apenas ao próprio usuário.
- Convite aleatório de 192 bits; busca apenas por código exato, sem listagem. Um usuário verificado que recebeu o código conhece o identificador do grupo, mas só lê seus dados depois do ingresso atômico.
- Entrar exige consumir convite válido e acrescentar apenas a própria conta. Usuários não podem alterar o dono, adicionar terceiros arbitrários ou recriar o histórico.
- Cada edição exige versão anterior e evento com o estado anterior real e novo estado. As regras com `getAfter` validam tudo junto. O cliente detecta versão antiga e pede reabrir a tela.
- Dose usa chave canônica medicamento/data/horário, versão do horário e versão da configuração revisada. Uma segunda administração requer confirmação da versão exata já existente.
- Transação rejeitada por corrida é relida, no máximo duas vezes, com os mesmos IDs e versões revisadas. Não se atualiza automaticamente a confirmação do usuário.
- Registros de histórico não podem ser alterados ou apagados pelos clientes. Data/hora do servidor identifica a sincronização; `clientAt` preserva o instante informado pelo aparelho.
- As regras protegem contra usuários externos e garantem autoria/consistência transacional. Integrantes autorizados continuam responsáveis por informar corretamente o que aconteceu; o software não comprova a administração física.

## Offline e migração

O `drac.db` original não é removido. Criar grupo copia o cadastro numa transação e importa administrações com IDs `legacy-ID`, tornando reexecução idempotente. A migração fica aberta até concluir; não permite convites ou operações novas nesse intervalo. Registros antigos mantêm responsável e dose histórica desconhecidos quando esses dados não existiam.

A projeção usa `shared_UID_GRUPO.db`. A tabela local `outbox` persiste a operação, horário, versões revisadas e seu ID aleatório antes da tentativa de gravação. Retry reutiliza esse ID: se já foi confirmado, não cria novo evento. Duplicidade/conflito fica retido para revisão explícita. Erros definitivos são exibidos; falhas temporárias ficam pendentes. A saída da conta é impedida enquanto houver registros pendentes.

Não há garantia de sincronização offline ou execução em segundo plano. Para reduzir risco de dose física duplicada, o app distingue pendência de confirmação remota e orienta comunicação entre cuidadores nesse período.

## Histórico e avisos

O evento contém UID/nome do autor autenticado, timestamp servidor, horário do aparelho quando pertinente, medicamento, dose e antes/depois. A tela mostra diferenças por campo e horários, sem despejar todo o documento. Desmarcar gera correção e preserva o evento anterior.

Um listener dos eventos novos mostra avisos do outro cuidador enquanto aberto. Importação e ações próprias não geram esse aviso. Alarmes locais permanecem; push remoto foi desativado nesta versão. Futuro push deve consumir os eventos em ambiente confiável, nunca conter chave administrativa no APK.

## Arquivos desta adaptação

Criados: `lib/repositories/spark_repository.dart`, `lib/services/audit_details.dart`, `functions/test/spark.integration.js`, `functions/NAO_UTILIZADO_SPARK.md`.

Modificados: `lib/services/shared_service.dart`, `lib/screens/compartilhamento/compartilhamento_screen.dart`, `lib/screens/historico/auditoria_screen.dart`, `pubspec.yaml`, `pubspec.lock`, `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `android/app/src/main/AndroidManifest.xml`, `functions/package.json`, `functions/pnpm-lock.yaml`, `README.md` e os três guias de configuração/arquitetura/verificação.

Movidos para `functions/legacy`: `index.js`, `domain.js`, testes antigos e o antigo `package-lock.json`. A configuração Android, `.firebaserc` e `google-services.json` foram conferidos e preservados. Arquivos gerados de plugins podem refletir a remoção de Messaging/Functions.

Referências: [Transações e validação atômica](https://firebase.google.com/docs/firestore/manage-data/transactions), [plano Spark](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
