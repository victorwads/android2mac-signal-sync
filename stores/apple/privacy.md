# Política de Privacidade / Privacy Policy

**Android 2 Mac Sinal Sync (Phone Router) — macOS e Android**
Última atualização / Last updated: 22 de outubro de 2026 / October 22, 2026

## Português (Brasil)

### Finalidade e dados utilizados
O aplicativo mostra no Mac o sinal celular e a bateria de um aparelho Android autorizado. Não exige conta. O aplicativo não envia esses dados a servidores do desenvolvedor e não inclui publicidade, rastreamento ou ferramentas de análise de uso.

Na rede local, o Android fornece ao Mac autorizado: identificador aleatório do aplicativo, modelo do aparelho, nível e potência do sinal quando disponíveis, tipo de conexão/rede celular, nome da operadora, idade da leitura, nível da bateria e estado de carregamento. Endereço de rede e porta são usados para localizar e conectar o aparelho. O pareamento troca um identificador aleatório do Mac, um nome de cliente e uma credencial de acesso; a aprovação exige conferir um código nas duas telas.

### Armazenamento e controle
No Mac, identificadores, nomes, apelidos, endereços, portas e preferências da interface são salvos nas preferências locais. As credenciais de pareamento ficam em um arquivo JSON local, em texto simples (sem criptografia pelo aplicativo), no Application Support do usuário, dentro da pasta do aplicativo. O aplicativo aplica permissões POSIX 0700 à pasta e 0600 ao arquivo, restringindo o acesso normal ao proprietário; isso não protege contra processos que já tenham acesso à mesma conta ou privilégios elevados. As leituras de sinal e bateria são mantidas em memória, sem histórico de medições implementado.

No Android, o identificador do aplicativo, a porta e os Macs aprovados com suas credenciais ficam nas preferências privadas do aplicativo. Essas preferências de conexão e autorização são excluídas das regras de backup em nuvem e transferência entre aparelhos do aplicativo. As leituras atuais ficam em memória. Não se trata de uma promessa sobre todos os backups ou recursos administrados pelo sistema operacional.

Você pode parar o monitoramento no Android, revogar a permissão de telefone nos ajustes do sistema e usar **Revogar Macs autorizados** no aplicativo Android para invalidar os acessos salvos. **Forget phone** no Mac remove o telefone e sua credencial local; isso não revoga, por si só, a autorização guardada no Android. Dados locais de configuração são mantidos enquanto necessários ao uso e até serem removidos pelas opções disponíveis ou pelos controles de armazenamento do sistema. A versão atual não acessa o Keychain e não migra nem exclui credenciais que versões anteriores possam ter gravado nele. Esses itens antigos permanecem no Keychain até sua remoção separada pelo usuário; **Forget phone** remove apenas a credencial do arquivo JSON atual, não os itens antigos de Keychain. Revogar os Macs autorizados no Android invalida o acesso guardado no telefone.

### Permissões e segurança
O Android solicita acesso ao estado do telefone para ler o sinal e pode solicitar permissão de notificações para o serviço de monitoramento. O Mac usa a rede local para descobrir e consultar o Android. Não são necessárias permissões de contatos, mensagens ou localização para a funcionalidade implementada.

**A comunicação local usa HTTP autenticado, sem TLS: não é criptografada.** Uma pessoa capaz de inspecionar o tráfego da rede pode capturar as informações e a credencial de acesso. A conferência do código não elimina esse risco. Utilize somente redes confiáveis, nunca redes públicas ou compartilhadas com pessoas não confiáveis. As permissões do arquivo local não criptografam o transporte nem o conteúdo JSON.

### Contato e serviços externos
Para dúvidas de privacidade ou solicitações sobre informações enviadas por você ao suporte: [victor.laureano@gmail.com](mailto:victor.laureano@gmail.com). Ao enviar e-mail ou abrir uma solicitação pública no [GitHub](https://github.com/victorwads/android2mac-signal-sync/issues), você compartilha voluntariamente o conteúdo com o destinatário ou publicamente, conforme o canal. Esses serviços seguem suas próprias políticas; não envie credenciais nem informações sensíveis. Esta política descreve os aplicativos, não a coleta independente das lojas, do sistema operacional ou dos serviços de suporte.

## English

### Purpose and information used
The app displays an authorized Android phone’s cellular signal and battery on your Mac. No account is required. The app does not send this information to developer-operated servers and contains no advertising, tracking, or usage analytics tools.

Over the local network, Android provides the authorized Mac with a random app identifier, device model, signal level and strength when available, connection/cellular network type, carrier name, reading age, battery level, and charging state. Network addresses and ports locate and connect the device. Pairing exchanges a random Mac identifier, a client name, and an access credential; approval requires comparing a code on both screens.

### Storage and your controls
On Mac, device identifiers, names, nicknames, addresses, ports, and interface preferences are stored in local preferences. Pairing credentials are stored in a local JSON file as plain text (not encrypted by the app), in the user’s Application Support directory inside the app’s folder. The app applies POSIX permissions 0700 to the folder and 0600 to the file, restricting normal access to its owner; this does not protect against processes already able to access the same account or elevated privileges. Signal and battery readings stay in memory; no measurement history is implemented.

On Android, the app identifier, port, and approved Macs with their credentials are stored in the app’s private preferences. The app’s cloud-backup and device-transfer rules exclude these connection and authorization preferences. Current readings stay in memory. This is not a guarantee about every operating-system-managed backup or feature.

You can stop Android monitoring, revoke phone permission in system settings, and use **Revogar Macs autorizados** in the Android app to invalidate saved access. **Forget phone** on Mac removes that phone and its local credential; it does not itself revoke the authorization stored on Android. Local configuration remains as needed for use until removed through available app options or operating-system storage controls. The current version does not access Keychain and does not migrate or delete credentials that earlier versions may have stored there. Those legacy items remain in Keychain until separately removed by the user; **Forget phone** removes only the credential from the current JSON file, not legacy Keychain items. Revoking approved Macs on Android invalidates the access stored on the phone.

### Permissions and security
Android requests phone-state access to read the signal and may request notification permission for the monitoring service. Mac uses the local network to discover and query Android. The implemented functionality does not require contacts, messages, or location permissions.

**Local communication uses authenticated HTTP without TLS: it is not encrypted.** Someone able to inspect network traffic may capture the information and access credential. Comparing the pairing code does not remove this risk. Use trusted networks only, never public networks or networks shared with untrusted people. Local file permissions do not encrypt network transport or the JSON contents.

### Contact and external services
For privacy questions or requests about information you send to support: [victor.laureano@gmail.com](mailto:victor.laureano@gmail.com). Emailing support or opening a public [GitHub issue](https://github.com/victorwads/android2mac-signal-sync/issues) voluntarily shares your content with its recipient or publicly, depending on the channel. Those services have their own policies; do not send credentials or sensitive information. This policy describes the apps, not independent collection by app stores, operating systems, or support services.
