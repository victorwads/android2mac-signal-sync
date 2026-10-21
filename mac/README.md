# Phone Signal Sync — macOS

Aplicativo nativo SwiftUI de barra de menus, sem ícone no Dock. Requer macOS 13 ou superior.

Esta base exibe um estado desconectado e a opção de sair. Comunicação com Android,
leitura de sinal e medição de tráfego ainda não estão implementadas.

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
open .build/Build/Products/Debug/PhoneSignalSync.app
```

O arquivo project.yml é a fonte de configuração do projeto. Após alterá-lo,
execute xcodegen generate novamente. O projeto Xcode, Info.plist e entitlements
são gerados e não precisam ser versionados.
