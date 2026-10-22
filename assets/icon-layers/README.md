# Sinal Sync — camadas da opção 1 aprovada

## Master

A fonte canônica é [logo.svg](<../logo.svg>) (Arco), com traços engrossados e curva incorporada à primeira barra. A assinatura WADS não possui quadrado interno.

[background](<master/background.svg>): base roxa opaca + assinatura WADS a 9%. [foreground](<master/foreground.svg>): dispositivos, seta, barras e 5G. Sobrepor ambos sem alterar posição ou escala. [composite](<master/composite.svg>) é referência plana, não uma camada adicional.

Todos os SVGs têm tamanho nominal 1024 × 1024 e viewBox 0 0 256 256. Sem máscara externa, fontes, raster ou efeitos de vidro pré-renderizados. Os interiores roxos dos dispositivos foram preservados para ocultar a assinatura, como no desenho aprovado.

## Android

Use exclusivamente [background Android](<android/background.svg>) e [foreground Android](<android/foreground.svg>) para adaptive. Arte e assinatura estão reduzidas a 60% em torno do centro para reservar a área de movimento/recorte. O fundo preenche o canvas inteiro; o tamanho lógico das duas camadas é 108 × 108 dp. O viewport central típico do launcher é 72 dp; a área segura de conteúdo é um círculo central de 66 dp de diâmetro. Não acrescente outra redução automática ao importar as camadas.

O [gerador Android](<../generate-android-icons.py>) já converte as camadas para VectorDrawable e cria os seletores adaptive API 26/33; os SVGs não são recursos instaláveis diretamente. Ele também gera cinco PNGs legados da fonte canônica arredondada. O monochrome dedicado usa traços brancos/interiores transparentes e não o foreground colorido com preenchimentos opacos. A assinatura fica somente na camada de fundo, não no ícone temático.

```sh
/usr/bin/python3 assets/generate-android-icons.py
/usr/bin/python3 assets/generate-android-icons.py --check
```

A geração requer Python 3 + ImageMagick 7, com Swift/AppKit no macOS ou `rsvg-convert` em outros hosts. Não renderize esta arte usando MSVG: ele pode omitir os strokes silenciosamente. O script verifica presença do foreground branco/coral e usa ImageMagick somente para resize PNG. Após gerar, compile/teste o app, inspecione o APK e revise ícones normal, mascarado e temático no launcher. Prévia estática não equivale a screenshot de dispositivo.

## macOS / Icon Composer

O [gerador macOS](<../generate-macos-icon.py>) cria o pacote [SinalSync.icon](<../../mac/Sources/SinalSync.icon>) sem modificar Android ou lojas. Fundo nativo **#782F9A**; os três grupos são, em ordem:

1. [Assinatura WADS](<macos/01-wads-signature.svg>): inferior, opacidade 9%, sem Liquid Glass. O SVG é opaco de propósito: a opacidade pertence ao modelo nativo.
2. [Dispositivos](<macos/02-devices.svg>): grupo intermediário com efeitos nativos.
3. [Transmissão](<macos/03-transmission.svg>): seta, barras e 5G com efeitos nativos.

```sh
/usr/bin/python3 assets/generate-macos-icon.py
/usr/bin/python3 assets/generate-macos-icon.py --check
# Após compilar o app, validar o catálogo produzido:
/usr/bin/python3 assets/generate-macos-icon.py --validate-compiled path/to/Assets.car
```

A validação compilada exige três grupos vetoriais, stack nativo com quatro camadas (incluindo fundo), lighting/specular/translucency e rendition 1024. A correção de schema do Xcode 27.1 usa `supported-platforms.squares` como array contendo `macOS`. Validar fonte/schema não significa que o app foi compilado ou que o efeito final foi aprovado. O ambiente de build precisa permitir os serviços e saídas nativas do compilador de ícones.

No Icon Composer, revisar Default, Dark e Mono e também Clear/Tinted: os interiores roxos dos dispositivos são preenchimentos reais, não transparência. Não importar o master/background ou master/foreground junto dos três SVGs, pois duplicaria conteúdo. Não aplicar máscara de cantos ao SVG. Não aceitar licença, contrato nem usar exportador interno do Composer sem autorização humana.

## Regenerar fontes compartilhadas

```sh
# Na raiz, somente após coordenar com os responsáveis pelas plataformas:
/usr/bin/python3 assets/export-icon-layers.py
/usr/bin/python3 assets/export-icon-layers.py --check
```

O [exportador](<../export-icon-layers.py>) sobrescreve alterações manuais nas camadas a partir de [logo.svg](<../logo.svg>); `--check` compara as nove camadas sem gravar. Não atualiza recursos nativos nem materiais de loja. Regenere cada plataforma separadamente depois. As fontes finais e seus geradores não dependem do histórico de rascunhos. Use somente os comandos isolados de cada plataforma para evitar sobrescritas cruzadas.

## Referências

- [Apple — Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
- [Android — Adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
