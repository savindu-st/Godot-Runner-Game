#!/bin/bash
set -e

# Export directory
export WEB_DIR="build/web"
mkdir -p "$WEB_DIR"

echo "=== Godot Web Build & Post-Processing ==="

# Check if we should run automatic headless export
if command -v godot &> /dev/null; then
    echo "Found godot CLI. Exporting headless..."
    export GODOT_SCRIPT_ENCRYPTION_KEY="${GODOT_SCRIPT_ENCRYPTION_KEY:-065175ea1561a1af86c1eb25013748ff5e5b5e0107edb7a578fe32812048a7ea}"
    godot --headless --path . --export-release "Web" "$WEB_DIR/index.html"
else
    echo "Godot CLI not found in PATH."
    echo "Please open Godot Editor, go to Project -> Export, select 'Web', and export to '$WEB_DIR/index.html'."
    read -p "Press Enter once you have exported the game via the editor..."
fi

# Run post-processing script
if [ -f scripts/post_export_web.py ]; then
    echo "Running post-export processing..."
    # Generate a unique build ID for local cache testing
    BUILD_ID=$(git rev-parse --short HEAD 2>/dev/null || echo "localdev")
    WEB_DIR="$WEB_DIR" BUILD_ID="$BUILD_ID" SIM_VERSION=11 python3 scripts/post_export_web.py
else
    echo "Error: scripts/post_export_web.py not found!"
    exit 1
fi

echo ""
echo "=== Post-Processing Complete ==="
echo "To deploy this build to GitHub Pages, commit the '$WEB_DIR' directory and push:"
echo "  git add build/web/"
echo "  git commit -m 'deploy: update game build'"
echo "  git push"
echo ""
echo "Starting local HTTPS server to test the build..."
if [ -f serve.py ]; then
    python3 serve.py
else
    echo "Starting simple python server on http://localhost:8000..."
    cd "$WEB_DIR" && python3 -m http.server 8000
fi
