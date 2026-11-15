#!/usr/bin/env bash
# Compile the rhythm toolkit to dist/rhythm.css (link it from any HTML page).
set -euo pipefail
cd "$(dirname "$0")"
export TC="$HOME/.local/toolchains"
export PATH="$TC/node/bin:$HOME/.local/bin:$PATH"
mkdir -p dist
npx sass --no-source-map src/main.scss dist/rhythm.css
echo "built dist/rhythm.css"