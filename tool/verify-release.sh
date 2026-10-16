#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

for file in index.html flutter_bootstrap.js flutter.js main.dart.js audio_cache.js manifest.json assets/FontManifest.json assets/fonts/MaterialIcons-Regular.otf canvaskit/canvaskit.js canvaskit/canvaskit.wasm canvaskit/chromium/canvaskit.js canvaskit/chromium/canvaskit.wasm; do
    if [ ! -s "public/$file" ]; then
        printf 'Missing release asset: public/%s\nRun ./tool/publish-web and commit public/.\n' "$file" >&2
        exit 1
    fi
done

grep -Fq '<base href="/">' public/index.html
grep -Fq 'https://ronflonflon.gus.cool/' public/index.html
if [ -s public/flutter_service_worker.js ]; then
    printf '%s\n' 'Unexpected app-shell service worker. Rebuild with ./tool/publish-web.' >&2
    exit 1
fi
printf '%s\n' 'Static release verified for https://ronflonflon.gus.cool/.'
