# Android 2 Mac Sinal Sync — Android

App Kotlin nativo, com Android 7.0 (API 24) como versão mínima.

## Disponível

- Tela para iniciar/parar o monitoramento.
- Intensidade de 0 a 4, potência em dBm quando inequívoca, operadora e tipo de rede.
- Callbacks de telefonia: recebe alterações quando o Android as disponibiliza.
- Serviço em foreground com notificação e ação de parar.
- Pedido de acesso ao estado do telefone e, no Android 13+, notificações. Não lê contatos, números de telefone ou localização.

A tela atualiza a apresentação a cada segundo e mostra a idade da última leitura. Isso não força o modem a fornecer uma leitura nova. Em dual SIM, usa a assinatura de dados padrão no momento de iniciar; reinicie após trocar o SIM de dados. 5G NSA pode aparecer como LTE. Em versões anteriores ao Android 10, dBm fica indisponível nesta implementação.

Servidor HTTP local implementado com descoberta DNS-SD (_phone2mac._tcp), credencial automática e status de bateria. Inicie o monitoramento para ver IPs e porta. No Mac, escolha o telefone descoberto e **Connect / approve on phone…**, compare o código e toque em **Permitir** no Android, ou **Add phone by IP…**. Apenas redes confiáveis: HTTP autenticado não criptografa o tráfego. A bateria é atualizada aproximadamente a cada segundo enquanto o processo está executando.

## Compilar

Abra esta pasta no Android Studio ou use o wrapper Gradle:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

O projeto existente usa AGP 9.4.1, SDK 37 e toolchain JVM 25, configurada pelo Gradle. Configure seu SDK no arquivo local.properties (não versionado), ou pelo Android Studio.

Com um aparelho autorizado via ADB:

```sh
./gradlew :app:installDebug
adb shell am start -n dev.wads.phone2mac.signalsync/.MainActivity
```

Ao abrir o app, o monitoramento inicia automaticamente; conceda acesso ao telefone na primeira abertura. O botão Iniciar permanece disponível após parar manualmente. A permissão de notificação é recomendada para visualizar o controle persistente; se negada, o Android ainda pode mostrar o serviço no gerenciador de tarefas ativas. Pare pela tela ou pela notificação. O app não inicia no boot e não reinicia automaticamente após encerramento pelo sistema.

## Limitações

- Validar sinal e comportamento em segundo plano em aparelho físico com SIM. Emuladores não representam fielmente o modem.
- Restrições de bateria e personalizações do fabricante podem interromper o serviço.
- O foreground service usa o tipo specialUse no Android 14+. Publicação na Play Store exige justificar esse uso e passar pela análise de políticas; a declaração não garante aprovação.
- Não há wake lock nem promessa de execução a cada segundo com a tela apagada.
