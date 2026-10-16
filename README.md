# Ronflonflon player

A basic Flutter web app for the [Ronflonflon radio archive](https://archive.org/details/ronflonflon-119-1987-01-14-ps-2760). No server, account, API key, or database service is needed.

## Deploy to Laravel Forge

Production domain: **https://ronflonflon.gus.cool/**. The repository includes the compiled app in **`public/`** so Forge can deploy it directly as a **Static HTML** site on branch **`main`**, with web directory **`/public`**. No server-side Flutter, Composer, Node, or database is required.

See **[deploy/README.md](deploy/README.md)** for the Forge deployment scripts (standard and zero-downtime), Nginx settings, DNS, and HTTPS setup. After changing the app, run `./tool/publish-web` and commit the updated `public/` alongside the source before pushing. `public/` is an intentional, tracked deployment artifact; `build/` remains ignored.

## Run in your browser

A local Flutter 3.35.4 SDK was installed in the ignored `.tools/` folder while building this project. The wrapper uses it when present, otherwise it uses Flutter from your PATH:

```sh
./tool/flutter pub get
./tool/flutter run -d chrome --web-port=7357
```

Keep the same hostname and port when returning: browser progress and audio storage belong to that exact origin. Chrome opens automatically. Safari and Firefox can also open the same local app URL while it is running. Flutter development commands stay running until you press `q` or Ctrl+C.

On a fresh checkout, install [Flutter](https://docs.flutter.dev/get-started/install) 3.35+ first. The `.tools/` SDK is not part of the application or a deployment.

## Serve locally with Laravel Herd

Open **https://ronflonflonplayer.test**. Herd is configured to link that hostname directly to this project's compiled `build/web/` directory, with a trusted local TLS certificate. HTTP redirects to HTTPS. No `flutter run` process is needed; Herd serves the compiled files.

After editing Dart code or web assets, rebuild to publish your changes to the Herd site:

```sh
./tool/flutter build web --release --no-web-resources-cdn
```

Then refresh the browser. Keep `build/web/` in place while using the site (`flutter clean` removes it). This hostname has its own saved progress, separate from `localhost:7357`.

To recreate the Herd configuration on another machine, first build as above, then run these commands from `build/web/`:

```sh
herd link ronflonflonplayer --secure
```

The link points only to compiled web files, not the source tree or local SDK. `.test` is a local development domain, not a publicly accessible deployment.

## Features

- Fetches the episode list from Archive.org's metadata API; listing never downloads audio.
- Orders by the episode number in filenames (including `260b`), not unreliable track tags or dates. Exact MD5 duplicates are hidden, preferring shorter filenames. Missing episode numbers are not invented.
- Search by episode number, date, or filename; optionally hide finished episodes.
- Play/pause, seek, skip back 15 seconds/forward 30 seconds, and manual “Mark finished.”
- Saves the current episode, per-episode play positions, and finished markers locally. Position is saved approximately every two seconds, on pause/seek/switch, and on lifecycle transitions. Abrupt termination may lose the last couple of seconds.
- Resumes only after a user gesture; reopening never autoplays or downloads audio.
- Downloads a selected episode fully before playing, and reuses it on subsequent visits.
- Removes the app's audio copy on natural completion or manual completion, keeping the episode and its finished marker in the list. Failed cleanup is retried at startup. Replaying downloads the episode again and clears its finished marker only after loading succeeds.
- Caches the catalog for use during network failures.

## Browser storage and downloads

Audio uses the browser **Cache Storage API**; listening history uses `shared_preferences` (browser local storage). Neither needs a backend. Downloads require HTTPS or `localhost`, plus Archive.org's CORS support. The app uses blob URLs for playback and revokes them when switching/completing. Network requests use `cache: no-store` to avoid deliberately creating an extra HTTP-cache copy. The app cannot purge caches managed internally by the browser or a CDN.

**This is not a streaming-first player.** Expect a wait for the first download (often 50–140 MB per recording). Progress is shown when the server supplies a content length. Interrupted downloads are discarded and retried from scratch. Only selected episodes are fetched; unfinished episodes remain cached until completed. Large downloads use memory while being assembled, so storage/memory limits matter on mobile browsers. The browser may evict caches under storage pressure. Quota/download errors are shown with a retry path rather than silently claiming a download succeeded.

Previously downloaded audio can play without a connection once the app is open and the catalog is available. **Offline app startup is not implemented**; this is not an installable offline PWA. Browser tab suspension/background behavior is browser-dependent. There is no native background-audio/lock-screen integration yet.

Progress is specific to this browser/device/origin, does not sync, and is removed if you clear site data. Private browsing may not retain it. An unreadable progress record is not automatically overwritten. Other tabs are not synchronized; use one player tab at a time.

Archive dates are displayed only when recognized in filenames; source typos are not corrected automatically. Dates may therefore be unavailable or incorrect even though episode ordering is correct. Content availability and distribution rights remain with the archive/uploader and rights holders; this is an independent player, not an assertion of redistribution rights.

## Validate and build

```sh
./tool/flutter analyze
./tool/flutter test
./tool/flutter test --platform chrome
node --test test/audio_cache_test.cjs
./tool/flutter build web --release
```

A macOS Chrome end-to-end smoke test is also included. It uses a fresh, isolated browser context, downloads the real first episode (about 52 MB), verifies playback/progress/reload/resume and natural-completion cleanup, and closes its local server afterward. Stop any other server on port 7357 first:

```sh
npm install --prefix .tools/browser --no-audit --no-fund playwright-core
node tool/browser_smoke.cjs
```

Deploy the contents of `build/web/` to any HTTPS static host. For a subdirectory, use `--base-href /your-path/`. The default Flutter web renderer may request CanvasKit assets from Google's CDN; use `--no-web-resources-cdn` at build time to serve those assets locally. Audio and catalog requests go directly to Archive.org.

## Structure

- `lib/models/`: archive filename parsing and local progress model.
- `lib/services/`: metadata/progress repositories and platform-specific audio storage.
- `lib/player/`: testable playback controller and `just_audio` adapter.
- `lib/ui/`: responsive Material episode list and player controls.
- `web/audio_cache.js`: browser download/cache/blob bridge, loaded before Flutter.
- `test/`: model/controller regression tests and browser-cache unit tests.

## Later: iOS

The Dart UI, controller, `just_audio`, and preferences are cross-platform. Conditional imports already select a native audio cache that downloads to Application Support and removes completed files. No iOS target has been generated or validated yet.

When ready, generate it with your installed Flutter SDK and choose your own reverse-DNS organization/bundle identifier:

```sh
flutter create --platforms=ios .
```

Then configure signing in Xcode and test on a real device. Before shipping, add background-audio/audio-session and lock-screen controls, review audio storage/backup policy, and check content rights. Background downloads are not currently implemented. Keep the web JS bridge for web builds; iOS does not use it.
