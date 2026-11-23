# Stable Quick Tunnel discovery

Cloudflare Quick Tunnel hostnames change when `cloudflared` restarts. An already-installed mobile app cannot discover a new hostname by contacting the old one. This Worker provides a stable HTTPS rendezvous on a `workers.dev` address; no purchased domain is needed. A Cloudflare account is required, and Worker/KV usage is subject to the account's free-plan limits.

## Deploy the Worker once

1. In the Cloudflare dashboard, enable a `workers.dev` subdomain if one is not already enabled.
2. Under **Workers & Pages > KV**, create a KV namespace named `karipa-tunnel-urls`.
3. Under **Workers & Pages**, create a Worker named `karipa-tunnel-discovery`, paste in [`worker.js`](worker.js), and deploy it.
4. In the Worker settings, add a KV namespace binding named `TUNNEL_URLS` linked to `karipa-tunnel-urls`.
5. Add a Worker secret named `PUBLISH_TOKEN` containing a new, random value. Use the same value for `KARIPA_TUNNEL_DISCOVERY_TOKEN` in `backend/.env`; never commit or print it.
6. Confirm the Worker URL is reachable at `https://<worker-name>.<workers-subdomain>.workers.dev/api/tunnel`. Before a tunnel is published it should return HTTP 503 with `No active tunnel is published`.

The Worker supports public `GET /api/tunnel` for mobile discovery. URL updates and clears require the `PUBLISH_TOKEN` bearer secret. It accepts only HTTPS `trycloudflare.com` origins and sets no-cache headers.

## Configure the backend

In the ignored `backend/.env`, set:

```dotenv
KARIPA_TUNNEL_DISCOVERY_URL=https://<worker-name>.<workers-subdomain>.workers.dev/api/tunnel
KARIPA_TUNNEL_DISCOVERY_TOKEN=<the-same-random-worker-secret>
```

Then from `backend/` run `npm run dev`. The supervisor starts the API and Quick Tunnel, writes the active origin to the ignored `backend/.tunnel-url` file, and publishes it to the Worker. On shutdown it stops both child processes and clears the published URL.

If `cloudflared` is missing, the local backend continues to run and the supervisor prints Windows installation instructions. If the Worker settings are absent or publication fails, the backend still runs, but automatic mobile discovery is unavailable until configured.

## Build the mobile app once

Build the APK with the stable Worker endpoint, not the temporary tunnel hostname:

```powershell
Set-Location C:\PathCraft\mobile
flutter build apk --release --dart-define=API_DISCOVERY_URL=https://<worker-name>.<workers-subdomain>.workers.dev/api/tunnel
```

Install this APK once. It caches the latest Quick Tunnel URL locally. If a cached tunnel stops responding, the app requests the latest URL from the Worker and retries the failed API request. Restarting the backend creates a new Quick Tunnel URL and updates the Worker; it does not require rebuilding the APK.

For production, set `API_BASE_URL` to the deployed API origin. That explicit setting takes precedence over tunnel discovery.
