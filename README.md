# `cacheComponents`: a `next.config.js` `Link` header duplicates and grows on every ISR regeneration

With `cacheComponents: true`, a `Link` header set in `next.config.js` `headers()`
is copied into the ISR cache entry whenever React's `onHeaders` emits its own
`Link` (here, a preload for an `<img fetchPriority="high">`). On every background
regeneration the cached copy grows by one, because Next snapshots the whole
`Link` value from the response (the config copy plus the copies replayed from the
previous cache entry) into the new cache entry. After N regenerations the response
carries N+1 copies of the config value. Without `cacheComponents` (plain
`export const revalidate = 2`) the header stays at one copy.

Reproduced on `next@16.4.3` (latest) and `next@16.5.0-canary.34` (canary).

## Steps

```sh
npm install
npm run build
npm start            # serves on :3000
./scripts/probe.sh   # in another terminal; PORT=xxxx to override
```

`probe.sh` requests `/` every 3 s (the page's `cacheLife` revalidates after 2 s)
and prints how many copies of `rel="llms-txt"` each response carries.

## Expected

One copy of the config `Link` value on every response:

```
request 1: llms-txt copies=1 ...
request 2: llms-txt copies=1 ...
...
```

## Actual (next 16.4.3)

```
request 1: llms-txt copies=1 x-nextjs-cache: HIT
request 2: llms-txt copies=1 x-nextjs-cache: STALE
request 3: llms-txt copies=2 x-nextjs-cache: STALE
request 4: llms-txt copies=3 x-nextjs-cache: STALE
request 5: llms-txt copies=4 x-nextjs-cache: STALE
request 6: llms-txt copies=5 x-nextjs-cache: STALE
request 7: llms-txt copies=6 x-nextjs-cache: STALE
request 8: llms-txt copies=7 x-nextjs-cache: STALE
--- Link header on the last response
Link: </llms.txt>; rel="llms-txt"
Link: </llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",</llms.txt>; rel="llms-txt",<https://example.com/hero.webp>; rel=preload; as="image"; fetchpriority="high"
```

The header grows without bound for as long as the server runs.

## Root cause

`packages/next/src/server/app-render/app-render.tsx` (compiled:
`next/dist/server/app-render/app-render.js`), unchanged between 16.4.2 and
16.5.0-canary.34:

```js
const setMetadataHeader = (name) => {
  metadata.headers ??= {};
  metadata.headers[name] = res.getHeader(name);
};
const appendHeader = (name, value) => {
  /* ... res.appendHeader(name, value) ... */
  setMetadataHeader(name);
};
```

React's `onHeaders` callback (only wired in the `cacheComponents` prerender path)
calls `appendHeader('Link', <image preload>)`. `setMetadataHeader` then stores
`res.getHeader('Link')` — the entire current value, which already contains the
`next.config.js` copy and every copy replayed from the previous cache entry — in
the new cache entry's headers. When serving, the cached headers are replayed with
`appendHeader` after the config header has been set, so each regeneration adds
one more copy.

A fix would record only the values the render itself appended (e.g. capture the
`Link` value before the render, or keep the appended values separately) instead of
snapshotting `res.getHeader(name)`.

## Workaround

Uncomment `reactMaxHeadersLength: 0` in `next.config.js`. React then emits no
`Link` header, so nothing is snapshotted (the cost: no early-hint preload `Link`
for the image). With it:

```
request 1: llms-txt copies=1 x-nextjs-cache: STALE
request 2: llms-txt copies=1 x-nextjs-cache: STALE
...
request 8: llms-txt copies=1 x-nextjs-cache: STALE
--- Link header on the last response
Link: </llms.txt>; rel="llms-txt"
```

## `next info`

```
Operating System:
  Platform: darwin
  Arch: arm64
  Version: Darwin Kernel Version 25.6.0: Fri Jul 31 19:18:48 PDT 2026; root:xnu-12377.161.14~5/RELEASE_ARM64_T6020
  Available memory (MB): 32768
  Available CPU cores: 12
Binaries:
  Node: 22.23.4
  npm: 10.9.9
  Yarn: 1.22.22
  pnpm: 12.11.2
Relevant Packages:
  next: 16.4.3 // Latest available version is detected (16.4.3).
  eslint-config-next: N/A
  react: 19.2.9
  react-dom: 19.2.9
  typescript: N/A
Next.js Config:
  output: N/A
```
