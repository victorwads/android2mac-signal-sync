# Identidade visual

A fonte é [logo.svg](<logo.svg>): base laranja **#F97316**, celular, seta de transmissão e barras de sinal em branco.

## Gerar os ícones

Requer Python 3 e ImageMagick 7 (`brew install imagemagick`). Na raiz:

```sh
python3 assets/generate-icons.py
```

No macOS, se o Python instalado estiver com problema, use `/usr/bin/python3 assets/generate-icons.py`.

O script gera:

- Preview PNG de 1024 × 1024 nesta pasta.
- Catálogo AppIcon do macOS com tamanhos de 16 a 1024 pixels, em `mac/Sources/Assets.xcassets`.
- PNGs Android para mdpi, hdpi, xhdpi, xxhdpi e xxxhdpi.
- Ícone adaptativo Android 8+ com fundo laranja e foreground vetorial.
- Variante monocromática para ícones temáticos Android 13+.

O SVG usa um retângulo `background` e um grupo `symbol`. O gerador converte os paths desse grupo para VectorDrawable; mantenha paths com coordenadas absolutas no viewBox 1024 × 1024, preenchimento branco e sem transforms ao editar. Os ícones adaptativos preservam espaço para recorte pelo launcher.

Após gerar, execute `xcodegen generate` dentro de `mac` para incluir o catálogo no projeto. Os ícones gerados são recursos dos apps e podem ser versionados; não são arquivos gerados pelo XcodeGen. A barra de menus usa uma imagem template monocromática desenhada pelo app, com apelidos, sinal, rede, bateria e carregamento; ela é independente da logo do aplicativo.
