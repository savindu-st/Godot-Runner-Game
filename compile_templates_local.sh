#!/bin/bash
set -e

KEY="065175ea1561a1af86c1eb25013748ff5e5b5e0107edb7a578fe32812048a7ea"
GODOT_VERSION="4.6.3"

echo "=== Installing SCons ==="
pip3 install --user scons || sudo apt-get install -y scons || true

echo "=== Setting up Emscripten SDK ==="
if [ ! -d "emsdk" ]; then
  echo "Cloning emsdk..."
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git
fi
cd emsdk
echo "Installing Emscripten 4.0.20..."
./emsdk install 4.0.20
./emsdk activate 4.0.20
source ./emsdk_env.sh
cd ..

echo "=== Cloning Godot Source ==="
if [ ! -d "godot" ]; then
  echo "Cloning Godot repository (version ${GODOT_VERSION}-stable)..."
  git clone --depth 1 --branch ${GODOT_VERSION}-stable https://github.com/godotengine/godot.git
fi

echo "=== Compiling Custom Web Templates ==="
cd godot
export SCRIPT_AES256_ENCRYPTION_KEY="$KEY"
echo "Starting compilation (using all CPU cores)..."
scons platform=web target=template_release threads=no -j$(nproc)

echo "=== Packaging Custom Web Templates ==="
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$TEMPLATE_DIR"

cd bin
# Locate compiled JS and WASM files using globbing
js_file=$(ls godot.web.template_release.wasm32*.js | head -n 1)
wasm_file=$(ls godot.web.template_release.wasm32*.wasm | head -n 1)

echo "Found compiled binaries: $js_file, $wasm_file"
mv "$js_file" godot.js
mv "$wasm_file" godot.wasm

worklet_js=$(ls godot.web.template_release.wasm32*.audio.worklet.js 2>/dev/null | head -n 1 || true)
if [ -n "$worklet_js" ]; then
  mv "$worklet_js" godot.audio.worklet.js
fi
position_js=$(ls godot.web.template_release.wasm32*.audio.position.worklet.js 2>/dev/null | head -n 1 || true)
if [ -n "$position_js" ]; then
  mv "$position_js" godot.audio.position.worklet.js
fi

# Download official templates zip to get base structure if missing
if [ ! -f "$TEMPLATE_DIR/web_release.zip" ]; then
  echo "Downloading base web templates..."
  wget -q https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz || \
  wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz
  
  unzip -q Godot_v${GODOT_VERSION}-stable_export_templates.tpz
  # templates are inside templates/
  cp templates/web_release.zip "$TEMPLATE_DIR/web_release.zip"
  cp templates/web_nothreads_release.zip "$TEMPLATE_DIR/web_nothreads_release.zip"
  cp templates/web_dlink_release.zip "$TEMPLATE_DIR/web_dlink_release.zip"
  cp templates/web_dlink_nothreads_release.zip "$TEMPLATE_DIR/web_dlink_nothreads_release.zip"
  rm -rf templates Godot_v${GODOT_VERSION}-stable_export_templates.tpz
fi

# Inject custom binaries into zips
for zip_file in "web_release.zip" "web_nothreads_release.zip" "web_dlink_release.zip" "web_dlink_nothreads_release.zip"; do
  ZIP_PATH="$TEMPLATE_DIR/$zip_file"
  if [ -f "$ZIP_PATH" ]; then
    echo "Injecting custom encryption binaries into $zip_file..."
    mkdir -p temp_zip
    unzip -q -o "$ZIP_PATH" -d temp_zip
    cp -f godot.js temp_zip/
    cp -f godot.wasm temp_zip/
    [ -f godot.audio.worklet.js ] && cp -f godot.audio.worklet.js temp_zip/
    [ -f godot.audio.position.worklet.js ] && cp -f godot.audio.position.worklet.js temp_zip/
    
    cd temp_zip
    zip -q -r -9 "$ZIP_PATH" *
    cd ..
    rm -rf temp_zip
  fi
done

echo "=== Custom templates compiled and installed successfully! ==="
echo "You can now export your game from the local Godot editor."
