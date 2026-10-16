# Deploy to Laravel Forge

Production URL: **https://ronflonflon.gus.cool/**

This is a static Flutter web application, not a Laravel application. The repository includes a ready-to-serve **`public/`** release (~30 MB). Forge does not need Flutter, Node, Composer, Artisan, a database, a daemon, or an `.env` file. Audio is downloaded directly from Archive.org to each listener's browser, not stored on your Forge server.

## 1. Publish this repository

The local repository uses branch **`main`**. Publish it to your GitHub account, including `public/`. No GitHub remote or deployment credentials are embedded in the project. Do not configure Git LFS for the release assets; Forge needs actual files, not LFS pointers.

## 2. Create the Forge site

- Select the **Static HTML** site type (or the equivalent static-site option in your Forge UI).
- Connect your GitHub repository and select branch **`main`**.
- Set the web/document directory to **`/public`**, relative to the repository root. Never serve the repository root or `web/` (which contains uncompiled sources).
- Configure the custom domain **`ronflonflon.gus.cool`**.
- Do not install Composer dependencies or add Laravel migration/build/restart commands.
- No persistent/shared application paths are needed. Listening progress lives in the browser.

If you already created a PHP/Laravel site, point it at `/public`, disable Composer installation, and replace its Laravel deploy script and PHP routing with the static configuration below. There is intentionally no `composer.json`, `artisan`, or `public/index.php`.

## 3. Set the deployment script

Forge does **not** automatically discover this repository's deployment scripts. Paste the appropriate script into the site's deployment script editor.

### Recommended: zero-downtime deployments

For a new site with zero-downtime deployments enabled, use:

```bash
set -eu

$CREATE_RELEASE()

cd "$FORGE_RELEASE_DIRECTORY"
sh tool/verify-release.sh

$ACTIVATE_RELEASE()
```

The macros are Forge syntax: paste them into Forge, do not execute this block in a local shell. Keep any release-management boilerplate required by your Forge version. No queue or PHP restart is needed for this static app. Forge clones the release; do not add `git pull` to this strategy. Verification runs before activation, so an incomplete release is not published.

### Standard deployments

For a site without zero-downtime deployments, paste the contents of [`forge-standard.sh`](forge-standard.sh):

```bash
set -eu
cd "$FORGE_SITE_PATH"
git pull --ff-only origin "$FORGE_SITE_BRANCH"
sh tool/verify-release.sh
```

Standard deployments update files in place; zero-downtime deployments are preferable to avoid briefly mixing old/new assets. Enable push-to-deploy if you want GitHub pushes to trigger deployment.

## 4. Nginx and HTTPS

1. Point the DNS `A` record for `ronflonflon.gus.cool` at your Forge server. Only add an `AAAA` record if the server's IPv6 is configured.
2. Issue a Let's Encrypt certificate in Forge and enable HTTP-to-HTTPS redirection. **HTTPS is required for audio Cache Storage.**
3. Confirm Nginx uses `index.html` and serves static files, rather than forwarding missing requests to `index.php`.
4. Use [`nginx-static.conf`](nginx-static.conf) as a **server-block fragment** in Forge's Nginx editor. Replace the existing `location /`, static-asset caching rule, and PHP handler with the supplied locations; do not append duplicate locations. Keep Forge's generated root, TLS, ACME (`.well-known`), hidden-file protections, and `forge-conf` includes unchanged. Forge manages the correct root for standard vs. zero-downtime deployments.
5. Ensure `.wasm` is served as `application/wasm` (normally already in the server's Nginx MIME types). If missing, add `application/wasm wasm;` inside the server's existing `mime.types` file's `types` block and validate/reload Nginx.

The app has no client-side path routes, so missing files should return **404**, not an HTML fallback. Stable Flutter asset filenames must be revalidated: the supplied rules use `expires -1` (`Cache-Control: no-cache`), not long-lived immutable caching. If you put a CDN/proxy in front of Forge, do not override this with a cache-everything rule. Brotli/gzip may be enabled by the server as usual.

Do not add restrictive Content Security Policy or cross-origin isolation headers without testing Archive.org downloads, blob audio playback, and CanvasKit/WebAssembly compilation.

## 5. First deployment checks

After deploying, open **https://ronflonflon.gus.cool/** and verify the episode list and playback. The browser contacts Archive.org; your server needs no Archive.org credentials.

```sh
curl -I https://ronflonflon.gus.cool/
curl -I https://ronflonflon.gus.cool/main.dart.js
curl -I https://ronflonflon.gus.cool/canvaskit/chromium/canvaskit.wasm
curl -I https://ronflonflon.gus.cool/.git/config
```

Expect HTTP 200 for the app/assets, `application/wasm` for the WASM asset, and 403/404 for `.git/config`. A Forge deployment health check can use `/`. Browser progress from the Herd `.test` domain will **not** transfer to this production origin.

## Publish future changes

On your development machine, with Flutter 3.35.4 (the SDK used for this release) and `rsync` installed:

```sh
./tool/flutter analyze
./tool/flutter test
node --test test/audio_cache_test.cjs
./tool/publish-web

git add lib web pubspec.yaml pubspec.lock public
# Include any other intentionally changed files, such as tests or tools.
git commit -m "Update player"
git push origin main
```

`tool/publish-web` builds a release with local CanvasKit assets, disables Flutter's app-shell service worker to avoid stale deployments, replaces the generated contents of `public/`, and verifies required assets. The app's audio Cache Storage is independent and remains enabled. **Never hand-edit `public/`: it is generated.** Source changes alone do not update the deployed app; commit the rebuilt `public/` too.

To roll back, redeploy a previous release in Forge (zero-downtime) or revert the source and corresponding `public/` together, then push. Deployments do not erase browser listening progress or cached audio. No production deployment or DNS changes are performed by the local setup scripts.
