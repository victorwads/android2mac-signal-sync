# Android 2 Mac Sinal Sync

O sinal do seu Android, direto na barra de menus do Mac.

A ideia é simples: quando você usa a internet do celular no computador, não deveria precisar pegar o aparelho só para descobrir se o sinal está fraco. Um app Android acompanha a rede celular e envia o estado pela rede local; um app macOS mostra essas informações de forma discreta na barra de menus.

## Estado atual

**Em desenvolvimento:** sincronização local de sinal e bateria implementada; builds e testes automatizados aprovados. A descoberta simultânea em dois celulares físicos e o fluxo visual completo ainda precisam de teste de aceitação manual. Consulte o [README em inglês](<README.md>) para instruções atuais de conexão e limitações de segurança.

Para conectar: inicie o monitoramento no Android, mantenha os aparelhos na mesma rede e selecione o telefone no menu do Mac. Use **Connect / approve on phone…** e confira o código de seis dígitos nas duas telas; toque em **Permitir** no celular. Se a descoberta falhar, use **Add phone by IP…** com IP e porta do celular. Cada telefone tem seu submenu; **Set nickname…** define o apelido salvo no Mac. Todos aparecem lado a lado com sinal (0–4 barras), rede (4G, 4G+, 5G, 5G+ quando informado), bateria e raio durante carregamento. A conexão usa HTTP autenticado, sem criptografia: utilize apenas redes confiáveis.

Já disponível:

- Base nativa macOS em SwiftUI, para macOS 13 ou superior.
- Aplicativo de barra de menus, sem janela principal e sem ícone no Dock.
- Estado inicial de celular desconectado e opção de sair no Mac.
- App Android em Kotlin com tela de controle, leitura de sinal e serviço com notificação persistente.
- Configuração reproduzível com XcodeGen e build via CLI.

Implementado nesta etapa:

- Consulta local a cada dois segundos com credencial automática após aprovação no celular.
- Sinal, tipo de rede, operadora, bateria e carregamento.
- Descoberta e múltiplos telefones simultâneos na barra, com apelidos persistentes e submenus independentes.
- Estados de desconexão e idade da leitura.

Planejado: medição de download, upload e consumo da sessão no próprio Mac.

A frequência real de atualização do sinal depende dos dados disponibilizados pelo Android e pelo modem. A comunicação usa HTTP local com token e descoberta DNS-SD/Bonjour.

## Arquitetura proposta

```text
Android (Kotlin)          Rede local          macOS (SwiftUI)
Sinal da rede celular ──────────────────────► Barra de menus
                                             Tráfego medido no Mac
```

O Android informa o sinal; o Mac mede o próprio tráfego. Os contadores da interface de rede incluem comunicação local, não apenas internet, e não representam o consumo total do celular ou a medição oficial da operadora.

## Executar no macOS

### Requisitos

- Mac com macOS 13 ou superior.
- Xcode completo instalado e selecionado como diretório de desenvolvimento.
- XcodeGen 2.44 ou superior.

Instale o XcodeGen usando Homebrew:

```sh
brew install xcodegen
```

### Gerar o projeto

```sh
git clone git@github.com:victorwads/android2mac-signal-sync.git
cd android2mac-signal-sync/mac
xcodegen generate
open PhoneSignalSync.xcodeproj
```

No Xcode, selecione o scheme `PhoneSignalSync` e execute com **Cmd+R**.

### Compilar e executar via CLI

Dentro da pasta `mac`:

```sh
xcodebuild -project PhoneSignalSync.xcodeproj \
  -scheme PhoneSignalSync \
  -configuration Debug \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO build

open ".build/Build/Products/Debug/Android 2 Mac Sinal Sync.app"
```

O comando produz um build local sem assinatura. Assinatura e distribuição precisam de configuração adicional.

## Organização

```text
mac/
├── project.yml                        # Configuração do XcodeGen
├── Sources/PhoneSignalSyncApp.swift    # Entrada do app e menu
├── README.md                          # Instruções específicas do macOS
└── .gitignore                         # Exclusões de geração e build
```

O app Android está na pasta `android`. Veja as [instruções de compilação e limitações](<android/README.md>). A comunicação local está implementada; veja o guia de conexão acima.

A fonte de configuração é [project.yml](<mac/project.yml>). O projeto Xcode, os plists, os entitlements e os artefatos de compilação são gerados localmente e ignorados pelo Git. Após mudar a configuração, execute `xcodegen generate` novamente.

- **Nome do app:** Android 2 Mac Sinal Sync
- **Bundle ID:** `dev.wads.phone2mac.signalsync`
- **Nome técnico do projeto e scheme:** `PhoneSignalSync`

Veja também as [instruções do app macOS](<mac/README.md>).
