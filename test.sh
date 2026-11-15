#!/usr/bin/env bash
# Self-contained test suite for rhythm.
# Compiles the SCSS with sass into mktemp fixtures and asserts the compiled
# CSS (clamp() math, custom properties, selectors, media queries), the demo
# wiring, reconfigurability via `@use ... with`, and compile-time error paths.
set -uo pipefail
cd "$(dirname "$0")"
export TC="$HOME/.local/toolchains"
export PATH="$TC/node/bin:$HOME/.local/bin:$PATH"

command -v npx >/dev/null 2>&1 || { echo "FAIL: npx not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $1"; }
bad(){ fail=$((fail+1)); echo "FAIL: $1"; }
has(){ # name file substring
  if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1 (missing '$3')"; fi
}
lacks(){ # name file substring
  if grep -qF -- "$3" "$2"; then bad "$1 (unexpected '$3')"; else ok "$1"; fi
}

# --- build + fresh compile ----------------------------------------------------
./build.sh >/dev/null 2>&1
if [ -s dist/rhythm.css ]; then ok "build.sh produces dist/rhythm.css"; else bad "build.sh output missing"; fi

npx sass --no-source-map src/main.scss "$TMP/rhythm.css" 2>"$TMP/err"
rc=$?
if [ "$rc" -eq 0 ]; then ok "sass compile exits 0"; else bad "sass compile exit $rc: $(cat "$TMP/err")"; fi
CSS="$TMP/rhythm.css"

# --- fluid type scale math ----------------------------------------------------
has "clamp() expressions present"        "$CSS" "clamp("
has "base step exact clamp"              "$CSS" "--rhythm-fs-base: clamp(1rem, 0.9583rem + 0.2083vw, 1.125rem)"
has "lg step exact clamp"                "$CSS" "--rhythm-fs-lg: clamp(1.44rem, 1.2537rem + 0.9317vw, 1.999rem)"
has "xs step swaps inverted anchors"     "$CSS" "--rhythm-fs-xs: clamp(0.6331rem, 0.6127rem + 0.1022vw, 0.6944rem)"

# --- vertical rhythm ----------------------------------------------------------
has "leading-base = 3 baseline rows"     "$CSS" "--rhythm-leading-base: 1.5rem"
has "leading-lg = 4 baseline rows"       "$CSS" "--rhythm-leading-lg: 2rem"
has "baseline token emitted"             "$CSS" "--rhythm-baseline: 0.5rem"
has "body line token emitted"            "$CSS" "--rhythm-line: 1.5rem"

# --- spacing tokens -----------------------------------------------------------
has "space-3 = one body line"            "$CSS" "--rhythm-space-3: 1.5rem"
has "space-8 = 4rem"                     "$CSS" "--rhythm-space-8: 4rem"

# --- selectors, responsive helpers, debug overlay ------------------------------
has "type utility class .rhythm-fs-xl"   "$CSS" ".rhythm-fs-xl"
has "min-width media query (above md)"   "$CSS" "@media (min-width: 48rem)"
has "range media query (below sm)"       "$CSS" "@media (width < 30rem)"
has "baseline debug overlay gradient"    "$CSS" "repeating-linear-gradient"

# --- demo wiring ----------------------------------------------------------------
if [ -f index.html ]; then ok "demo index.html exists"; else bad "demo index.html missing"; fi
has "demo links the compiled CSS"        "index.html" "dist/rhythm.css"

# --- reconfigurability: @use config with (...) ------------------------------------
cat > "$TMP/custom.scss" <<'EOF'
@use "config" with ($prefix: "acme", $baseline: 0.25rem, $space-steps: 4);
@use "main";
EOF
npx sass --no-source-map --load-path=src "$TMP/custom.scss" "$TMP/custom.css" 2>"$TMP/err2"
rc=$?
if [ "$rc" -eq 0 ]; then ok "reconfigured compile exits 0"; else bad "reconfigured compile: $(cat "$TMP/err2")"; fi
has "custom prefix tokens emitted"       "$TMP/custom.css" "--acme-fs-base"
has "custom baseline honoured"           "$TMP/custom.css" "--acme-baseline: 0.25rem"
has "custom space-steps honoured"        "$TMP/custom.css" "--acme-space-4"
lacks "default prefix fully replaced"    "$TMP/custom.css" "--rhythm-"
lacks "space tokens trimmed to 4"        "$TMP/custom.css" "--acme-space-5"

# --- compile-time error paths -----------------------------------------------------
cat > "$TMP/badunits.scss" <<'EOF'
@use "fluid";
.x { width: fluid.fluid(1rem, 20px); }
EOF
npx sass --no-source-map --load-path=src "$TMP/badunits.scss" "$TMP/badunits.css" >/dev/null 2>&1
if [ $? -ne 0 ]; then ok "incompatible units rejected at compile time"; else bad "incompatible units accepted"; fi

cat > "$TMP/badstep.scss" <<'EOF'
@use "fluid";
.x { font-size: fluid.step("huge"); }
EOF
npx sass --no-source-map --load-path=src "$TMP/badstep.scss" "$TMP/badstep.css" >/dev/null 2>&1
if [ $? -ne 0 ]; then ok "unknown scale step rejected at compile time"; else bad "unknown scale step accepted"; fi

echo "----------------------------------------"
echo "rhythm: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || exit 1