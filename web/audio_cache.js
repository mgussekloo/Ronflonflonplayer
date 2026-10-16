/* The browser owns HTTP caching; this cache is the app's explicit offline copy. */
(() => {
  'use strict';
  const cacheName = 'ronflonflon-audio-v1';
  let objectUrl = null;
  const release = () => {
    if (objectUrl) URL.revokeObjectURL(objectUrl);
    objectUrl = null;
  };
  window.ronflonflonCache = {
    release,
    async prepare(url, onProgress) {
      release();
      if (!window.isSecureContext || !window.caches) {
        throw new Error('Audio storage requires HTTPS or localhost.');
      }
      const cache = await caches.open(cacheName);
      let response = await cache.match(url);
      if (!response) {
        const abort = new AbortController();
        let timer;
        const resetTimeout = () => {
          clearTimeout(timer);
          timer = setTimeout(() => abort.abort(), 60000);
        };
        resetTimeout();
        try {
          // Avoid an additional, uncontrollable copy in the browser HTTP cache.
          const download = await fetch(url, { cache: 'no-store', signal: abort.signal });
          if (!download.ok || download.type === 'opaque') {
            throw new Error(`Archive.org download failed (${download.status}).`);
          }
          const total = Number(download.headers.get('content-length'));
          const chunks = [];
          let received = 0;
          const reader = download.body.getReader();
          onProgress(-1);
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            chunks.push(value);
            received += value.byteLength;
            resetTimeout();
            onProgress(total > 0 ? Math.min(received / total, 1) : -1);
          }
          if (received === 0) throw new Error('Archive.org returned an empty audio file.');
          const blob = new Blob(chunks, { type: 'audio/mpeg' });
          response = new Response(blob, { headers: { 'Content-Type': 'audio/mpeg' } });
          // Quota failures are visible: never pretend an episode is saved offline.
          await cache.put(url, response.clone());
        } finally {
          clearTimeout(timer);
        }
      }
      objectUrl = URL.createObjectURL(await response.blob());
      onProgress(1);
      return objectUrl;
    },
    async remove(url) {
      const cache = await caches.open(cacheName);
      await cache.delete(url);
    },
  };
})();
