# Identidade visual

A fonte canônica aprovada é [logo.svg](<logo.svg>) (Arco): base roxa **#782F9A**, dispositivos/5G em branco quente **#FFF8FD** e transmissão em coral **#FF693D**. Os traços estão engrossados e a curva integra a primeira barra de sinal. A assinatura WADS aparece a 9%, sem quadrado interno. [logo.svg](<logo.svg>) é a cópia canônica; não retomar o desenho laranja antigo.

## Fontes e camadas

Consulte as [instruções das camadas](<icon-layers/README.md>). As fontes têm tamanho nominal 1024 × 1024 e viewBox 0 0 256 256; o sistema aplica a máscara externa no adaptive Android e no ícone nativo macOS.

O [exportador de camadas](<export-icon-layers.py>) recria as fontes derivadas de [logo.svg](<logo.svg>). Ele sobrescreve os SVGs compartilhados: coordene antes de executar, depois regenere e valide cada plataforma separadamente. Não altera os recursos instaláveis dos apps.

```sh
# Somente após coordenar uma mudança de fonte:
python3 assets/export-icon-layers.py
python3 assets/export-icon-layers.py --check
```

## Gerar e verificar Android

Use o [gerador exclusivo Android](<generate-android-icons.py>). Requer Python 3, ImageMagick 7 e Swift/AppKit no macOS, ou `rsvg-convert` nos outros hosts. O renderer interno MSVG do ImageMagick omite strokes desta arte; por isso o script usa um renderer SVG completo e deixa somente o resize PNG para ImageMagick. No host atual, prefira `/usr/bin/python3` se o Python do PATH estiver com framework inválido.

```sh
python3 assets/generate-android-icons.py
python3 assets/generate-android-icons.py --check
cd android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

O script escreve apenas os dez recursos `signal_launcher` em [res](<../android/app/src/main/res>): cinco PNGs legados (48, 72, 96, 144 e 192 px), três VectorDrawables e dois seletores adaptive (API 26/33). O fundo contém a assinatura; o foreground mantém os interiores roxos opacos. A variante monocromática usa traços brancos e interiores transparentes, sem assinatura de fundo. `--check` regenera temporariamente e compara todos os recursos sem alterar arquivos versionados. O manifesto já referencia `signal_launcher` para ícone normal e redondo.

As camadas adaptive têm 108 × 108 dp, com arte a 60% da fonte; não aplique uma segunda redução. Verifique também máscara/viewport do launcher, ícone temático em Android 13+ e recursos presentes no APK final. Build/unit tests não substituem essa inspeção visual.

## Gerar e verificar macOS

Use o [gerador exclusivo macOS](<generate-macos-icon.py>). Este repositório contém um app macOS, não um app iOS.

```sh
python3 assets/generate-macos-icon.py
python3 assets/generate-macos-icon.py --check
cd mac
xcodegen generate
xcodebuild -project PhoneSignalSync.xcodeproj -scheme PhoneSignalSync -configuration Debug build
# Depois, validar o catálogo nativo compilado:
python3 ../assets/generate-macos-icon.py --validate-compiled path/to/Assets.car
```

O gerador escreve somente o pacote [SinalSync.icon](<../mac/Sources/SinalSync.icon>), com fundo nativo e três camadas semânticas: assinatura, dispositivos e transmissão. O [projeto](<../mac/project.yml>) usa `ASSETCATALOG_COMPILER_APPICON_NAME: SinalSync`. Consulte as [instruções Apple das camadas](<icon-layers/README.md>) para efeitos, variantes e revisão no Icon Composer. A geração/verificação do pacote não prova, por si só, que o app foi compilado ou que o resultado Liquid Glass foi revisado. O build requer Xcode e permissões locais adequadas; não aceite contratos/licenças automaticamente.

A barra de menus usa imagem template desenhada pelo app e é independente da logo do aplicativo.

## Material final de loja

O [ícone Google Play](<store/google-play/icon-512.png>) é PNG32 512 × 512, sRGB e opaco, derivado da [composição master quadrada](<icon-layers/master/composite.svg>). O [gerador Play](<store/google-play/generate.py>) produz somente esse ícone, nunca feature graphics ou outros rascunhos.

```sh
python3 assets/store/google-play/generate.py
python3 assets/store/google-play/generate.py --check
```

A [prévia final](<logo-preview.png>) permanece como referência documental. As fontes, camadas e geradores finais são autossuficientes; históricos de design, ZIPs/prévias intermediárias, geradores antigos e diagnósticos locais não fazem parte da cadeia de geração final.

No macOS, o ícone da App Store vem do pacote nativo compilado no app, não de uma referência PNG plana. Nenhum gerador publica ou atualiza lojas. Uploads, mudanças de ficha, contratos e releases exigem autorização humana específica.
