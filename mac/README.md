# Android 2 Mac Sinal Sync — macOS

Aplicativo nativo SwiftUI de barra de menus, sem ícone no Dock. Requer macOS 13 ou superior.

Descobre múltiplos celulares via Bonjour, consulta sinal e bateria a cada dois segundos e mostra todos lado a lado na barra, com apelidos salvos, barras de sinal, tecnologia de rede, bateria e raio de carregamento. Use Set nickname… no submenu para editar o apelido. Cada telefone tem submenu com pareamento por aprovação no Android, detalhes e remoção. Há conexão manual por IPv4 e porta. Tokens ficam no Keychain. Transporte HTTP sem TLS: use somente redes confiáveis. Medição de tráfego ainda não implementada. Veja o [guia principal](<../README.md>) para conectar.

## Requisitos

- Xcode completo, selecionado como diretório de desenvolvimento.
- XcodeGen 2.44 ou superior (`brew install xcodegen`).

## Gerar e abrir

Na raiz do repositório:

```sh
cd mac
xcodegen generate
open PhoneSignalSync.xcodeproj
```

Selecione o scheme PhoneSignalSync e execute com Cmd+R. O ícone de antena aparece
na barra de menus. Para distribuição, configure sua equipe de assinatura no Xcode.

## Compilar e executar via CLI (sem assinatura, para desenvolvimento local)

Dentro de mac:

```sh
xcodebuild -project PhoneSignalSync.xcodeproj \
  -scheme PhoneSignalSync -configuration Debug \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
open ".build/Build/Products/Debug/Android 2 Mac Sinal Sync.app"
```

O arquivo project.yml é a fonte de configuração do projeto. Após alterá-lo,
execute xcodegen generate novamente. O projeto Xcode, Info.plist e entitlements
são gerados e não precisam ser versionados.
