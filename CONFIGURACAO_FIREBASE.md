# Drác App — configuração gratuita Spark

Esta versão usa somente Firebase Authentication (e-mail/senha) e Cloud Firestore. Não usa Cloud Functions, Cloud Run, Storage nem servidor pago. Não vincule uma conta de faturamento. O plano Spark tem cotas; quando uma cota é atingida, o serviço pode parar temporariamente em vez de cobrar excedentes. Consulte [os planos oficiais](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

## O que já está configurado

- Projeto local vinculado a `drac-app-54d3e` em `.firebaserc`.
- `android/app/google-services.json` corresponde a esse projeto e ao pacote `com.example.drac_app`.
- Configuração Android do Google Services mantida. Nenhuma chave privada de servidor foi adicionada.
- `firebase.json` publica apenas regras e índices do Firestore. Não há configuração de Functions.

## No notebook: publicar as regras novas

No PowerShell, execute:

```powershell
Set-Location 'C:\Users\pamel\drac_app'
firebase.cmd use drac-app-54d3e
firebase.cmd deploy --only firestore:rules,firestore:indexes --project drac-app-54d3e
```

Se a CLI pedir autenticação, rode `firebase.cmd login` e repita a publicação. Não execute comandos de publicação de Functions. As regras precisam ser publicadas antes de criar o grupo nesta versão; as regras da versão anterior bloqueavam gravações diretas pelo aplicativo.

No [Firebase Console](https://console.firebase.google.com/project/drac-app-54d3e/overview), confira:

1. O projeto continua no **Spark**. Não é necessário preencher cartão ou efetuar pré-pagamento.
2. **Build → Authentication → Sign-in method → E-mail/senha** está habilitado.
3. **Build → Firestore Database → Regras** mostra as regras publicadas. Não use regras públicas como `allow read, write: if true`.
4. O banco utilizado é o **(default)**. Se ele já existe, não crie outro banco.

Não é necessário recriar o projeto Firebase, baixar outro JSON ou configurar Cloud Messaging. O comando de publicação acima ainda deve ser executado por você; os testes automatizados usaram somente o emulador local.

## Compilar e instalar

```powershell
Set-Location 'C:\Users\pamel\drac_app'
& 'C:\Users\pamel\develop\flutter\bin\flutter.bat' pub get
& 'C:\Users\pamel\develop\flutter\bin\flutter.bat' analyze
& 'C:\Users\pamel\develop\flutter\bin\flutter.bat' test
& 'C:\Users\pamel\develop\flutter\bin\flutter.bat' build apk --debug
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" install -r -t '.\build\app\outputs\flutter-apk\app-debug.apk'
```

Conecte um celular por vez para o último comando. Se houver vários, acrescente `-s 'IDENTIFICADOR_MOSTRADO_EM_DEVICES'` antes de `install`. Use atualização por cima (`-r`): **não desinstale o aplicativo e não limpe seus dados**, pois isso apaga o banco local. Se houver erro de assinatura, pare e preserve um backup antes de resolver; não desinstale como tentativa de correção.

O APK debug é adequado para este estudo e instalação manual, não para publicação na Play Store.

## No celular: vincular vocês dois

1. No celular que contém os medicamentos atuais, abra **Configurações → Cuidado compartilhado**.
2. Crie sua conta com seu nome, e-mail e senha. Abra o link de confirmação recebido por e-mail e toque em **Já confirmei meu e-mail**.
3. Toque em **Criar grupo e importar dados deste celular**. Aguarde a conclusão. O `drac.db` original fica preservado e separado dos dados compartilhados.
4. Toque em **Gerar convite (responsável pelo grupo)** e copie o código. Ele funciona uma única vez e expira em aproximadamente 24 horas. Gerar outro invalida o anterior.
5. Seu irmão instala a mesma versão, cria uma conta diferente e confirma o e-mail.
6. Ele cola o código em **Código de convite** e toca em **Entrar no grupo pelo convite**. **Ele não deve criar outro grupo.**

Esta versão foi limitada a dois integrantes por grupo. O dono é quem cria o convite. Os dados locais antigos do segundo celular permanecem separados e não substituem o grupo. Não há tela de troca de grupo/remoção de integrante nesta versão.

Se a importação for interrompida, use **Retomar importação interrompida (celular original)**. Antes de compartilhar, conclua essa etapa. Registros antigos têm responsável desconhecido; o aplicativo não inventa quem administrou.

## Testar nos dois celulares

Use um medicamento claramente identificado como teste; não marque doses reais só para experimentar.

1. Deixe os dois aplicativos abertos e conectados. Crie um medicamento de teste em um aparelho: ele deve aparecer no outro sem atualizar.
2. Edite dose, observações e horários. Confira também o **Histórico de ações**, com responsável e valores anteriores/novos.
3. Registre a dose de teste no primeiro aparelho. No segundo, confira o nome do responsável e tente registrar novamente: é necessária uma confirmação explícita de outra administração.
4. Desmarque/corrija a dose: os dois aparelhos devem atualizar e o histórico anterior permanecer.
5. Abra a edição nos dois aparelhos; salve em um e tente salvar a edição antiga no outro. A segunda gravação deve avisar conflito e pedir reabertura.
6. Desligue a internet em um aparelho e registre uma dose de teste. Ela deve ficar **pendente**, sem afirmar que foi confirmada na nuvem. Registre o mesmo horário no outro; reconecte o primeiro. A fila deve exigir revisão da duplicidade.
7. Feche e reabra o aplicativo com pendências: a fila permanece no aparelho. Exclua o medicamento de teste ao terminar.

Não há comunicação entre celulares sem internet. Enquanto uma ação estiver pendente, conversem antes de administrar uma dose real. A proteção compara medicamento + dia + horário; não avalia clinicamente se doses em horários diferentes estão próximas demais.

## Notificações e offline

Com o app aberto, snapshots atualizam as telas e mostram avisos de ações do outro cuidador. Com o app fechado, **não há push remoto**. Os alarmes locais Android existentes foram mantidos. Os eventos imutáveis permitem acrescentar futuramente um serviço de push confiável, sem colocar credenciais privadas no aplicativo.

Os dados já carregados ficam disponíveis localmente. Administrações/correções têm fila SQLite e tentativas idempotentes ao reabrir/manter o app aberto. Edição/criação/exclusão de cadastros, convites e importação exigem internet. Transações Firestore não concluem offline.

## Testes de segurança locais (opcional)

Os testes JavaScript ficam em `functions/test`, somente por compatibilidade com a pasta antiga. Eles não são Functions e não são publicados. Use Node.js, Java e pnpm instalados no notebook:

```powershell
Set-Location 'C:\Users\pamel\drac_app\functions'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
pnpm.cmd install --frozen-lockfile
pnpm.cmd test
```

Alternativa exata usando as ferramentas já encontradas neste notebook:

```powershell
Set-Location 'C:\Users\pamel\drac_app\functions'
$nodeDrac = 'C:\Users\pamel\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$(Split-Path $nodeDrac);$env:PATH"
& $nodeDrac '.\node_modules\firebase-tools\lib\bin\firebase.js' emulators:exec --config '..\firebase.json' --only firestore --project demo-drac 'node --test test/spark.integration.js'
```

`demo-drac` é o projeto fictício de testes, separado do seu banco real.
