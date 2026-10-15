#!/usr/bin/env bash
# Réglages d'import des textures de personnages : compression VRAM + mipmaps (cartes de normales en RGTC).
cd "$(dirname "$0")/.."
for f in assets/character/*.png.import; do
	sed -i 's/^compress\/mode=0/compress\/mode=2/; s/^mipmaps\/generate=false/mipmaps\/generate=true/' "$f"
done
for f in assets/character/*_n.png.import; do
	sed -i 's/^compress\/normal_map=0/compress\/normal_map=1/' "$f"
done
