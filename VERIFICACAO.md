# Drác — resultado da implementação e verificação

Data: 27/09/2026. Projeto alterado diretamente: `C:\Users\pamel\drac_app`.

## Resultado

- Autenticação por e-mail/senha e confirmação de e-mail implementadas.
- Grupo compartilhado e convites de uso único implementados.
- Firestore com listeners, histórico com autoria e comparação de versões implementados.
- Administração com transação, aviso de duplicidade e confirmação de uma dose adicional implementados.
- Fila SQLite de doses pendentes com IDs estáveis e revisão de conflitos implementada.
- Funções de notificações FCM e registro/remoção de tokens implementadas.
- Regras de segurança restringindo leitura ao grupo e gravações ao servidor implementadas.
- Importação dos dados antigos e banco compartilhado separado implementados.

O Firebase de produção ainda não está configurado. O aplicativo instalado funciona no modo local. Contas reais, sincronização entre dois celulares e entrega de push precisam ser verificadas depois de seguir `CONFIGURACAO_FIREBASE.md` e publicar as funções e regras.

## Verificações realizadas

| Verificação | Resultado |
|---|---|
| `flutter analyze lib test integration_test` final | Sem apontamentos |
| Testes Flutter, incluindo os avisos de dose duplicada e offline | 14 passaram |
| Testes da lógica do servidor e das regras, com Firestore emulado | 17 passaram |
| Teste de navegação e persistência no Samsung conectado | 1 passou |
| `flutter build apk --debug` final | APK compilado |
| Instalação e abertura da versão normal no Samsung SM-S928B | Concluídas |
| Registros de execução da versão final | Sem exceções Flutter não tratadas ou falha fatal Android detectadas |
| Inspeção da tela inicial | Aplicativo aberto com os medicamentos existentes |

Foram testados acesso de terceiros, leitura sem login, e-mail não verificado, tentativa de falsificar histórico, uso repetido de convite, duas administrações concorrentes, repetição idempotente, correção com versão antiga, edição concorrente, retenção do histórico após exclusão e repetição de lotes de importação.

Não houve teste de envio FCM em um projeto real, nem teste com duas sessões de aplicativo conectadas a uma nuvem de produção. A verificação de concorrência ocorreu no servidor de testes com Firestore emulado. O teste Android percorreu as telas e usou um banco separado para testar a persistência, sem registrar medicações reais.

## Preservação dos dados do aparelho

Foi salvo um backup antes da primeira instalação. Depois do ciclo de testes, o pacote do aplicativo estava ausente do aparelho. A versão normal foi reinstalada, o banco original foi restaurado e uma nova cópia foi extraída para comparação. A comparação verificou todos os campos de todas as linhas, não apenas as quantidades.

| Tabela | Antes | Depois | Conteúdo |
|---|---:|---:|---|
| Perfil (`drac`) | 0 | 0 | Idêntico |
| Tratamentos | 0 | 0 | Idêntico |
| Medicamentos | 3 | 3 | Idêntico |
| Horários | 3 | 3 | Idêntico |
| Administrações | 16 | 16 | Idêntico |

O arquivo `drac-backup-antes-da-atualizacao.tar` contém o banco original. Guarde-o. Ele é uma cópia do banco SQLite, não um backup completo das preferências Android ou da futura nuvem.

**O despertador estava desativado na conferência final.** Se quiser os avisos sonoros, entre em **Config. → Despertador**, confira as permissões de notificações/alarmes e ative-o. A reinstalação pode redefinir preferências e permissões do Android; elas não estavam incluídas no backup do banco.

## Próximo passo

Siga `CONFIGURACAO_FIREBASE.md`, a partir da criação do projeto Firebase. O guia contém as telas do console, opções, arquivo necessário, caminho de instalação, comandos e roteiro de teste com dois celulares. A lista de arquivos e a estrutura do banco estão em `ARQUITETURA_COMPARTILHAMENTO.md`.
