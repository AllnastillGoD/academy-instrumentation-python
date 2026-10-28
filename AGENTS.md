# Working in this repo (Base44 dev environment)

Sandbox/dev wiring lives in `docker-compose.base44.yml` (see `.base44/environment.json`).
It runs the app from the cloned source; the project's own `docker-compose.yaml` /
`./run` build production images (Parcel bundle baked into nginx, `COPY . .`) and must
**not** be used here — edits would be invisible.

## Start / inspect

```bash
docker compose -f docker-compose.base44.yml up -d --build   # build only needed on dependency changes
docker compose -f docker-compose.base44.yml ps
docker compose -f docker-compose.base44.yml logs -f backend-for-frontend
```

Entry point: <http://localhost:3000> (host port 3000 → nginx `web`). Only that port is
public; `backend-for-frontend` is also published on 10115 for direct curl-ing.

## Non-obvious things

* **Single origin by design.** `services/web/src/index.js` fetches the relative
  `POST /backend/createPicture`. nginx (`web`, on port 3000) serves the page *and*
  proxies `/backend/` → `backend-for-frontend:10114`, mirroring the project's own
  `services/web/nginx.conf`. Renaming the `backend-for-frontend` service breaks it.
* **Service discovery is by compose service name.** `services/backend-for-frontend-python/o11yday_lib.py`
  hardcodes `http://meminator:10114`, `http://phrase-picker:10114`, `http://image-picker:10114`.
  Don't rename those services in the compose file.
* **The frontend is served unbundled from source** (`.base44/nginx.dev.conf`, root `/srv/web`),
  so `static/index.html`'s `../src/index.js` resolves to `/src/index.js` and no Parcel
  build/install is needed. Static edits show up on a browser refresh (`reload_preview`);
  there is no live-reload dev server for it.
* **Python services auto-reload.** Each runs `flask run --debug` with its service dir
  bind-mounted at `/app`, so source edits restart the app in place. Dependencies are
  installed in the image built from `.base44/python-service.Dockerfile` (requirements
  only — source is never baked in); **after changing a `requirements.txt`, rebuild**:
  `docker compose -f docker-compose.base44.yml up -d --build <service>`.
* **`meminator` needs ImageMagick + the Angkor font.** The dev image installs
  `imagemagick fontconfig` (via the `APT_PACKAGES` build arg) and
  `services/meminator-python/Angkor` is mounted at
  `/usr/share/fonts/truetype/angkor` with `fc-cache -f` at startup; `convert -font
  Angkor-Regular` fails without it.
* **`SERVICE_PATH`** selects the implementation, like the upstream repo does:
  `services` (default, uninstrumented lab starter) or `services-implemented-version`.
  Set it in a repo-root `.env` (gitignored) and rebuild.
* **No credentials are required to run this app.** On this branch the `services/`
  version has no OpenTelemetry instrumentation (the OTEL imports in
  `services/web/src/index.js` are commented out, and the Python requirements have no
  OTEL packages), so `HONEYCOMB_API_KEY` / `OTEL_*` are unused — the compose file
  deliberately doesn't pass them. They only become relevant once the lab's
  instrumentation step is done; wire `HONEYCOMB_API_KEY` in as a Base44 secret then.
* **Outbound internet is needed at runtime:** `image-picker` returns URLs from the
  public S3 bucket `random-pictures` (overridable with `BUCKET_NAME`) and `meminator`
  downloads the chosen image.

## Verify it works

```bash
curl -s http://localhost:3000/backend/health            # {"message": "I am here", ...}
curl -s -o /tmp/out.png -w '%{http_code} %{content_type}\n' \
  -X POST http://localhost:3000/backend/createPicture    # 200 image/png  (~370 KB)
```

The end-to-end check is that last POST: it walks web → backend-for-frontend →
phrase-picker + image-picker → meminator (download + ImageMagick annotate) and returns
a PNG. In the UI, `GO` on <http://localhost:3000> does exactly this.

There is no test suite in this repo. `scripts/loadgen.sh` loops the create-picture call
but targets the upstream port 8080 — use 3000 here.
