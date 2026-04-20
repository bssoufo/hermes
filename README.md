# Hermes Agent on Elestio

Self-hosted [Hermes Agent](https://hermes-agent.nousresearch.com/) gateway (OpenAI-compatible API) behind Elestio's managed HTTPS.

## Deploy

1. Push this repo to GitHub / GitLab / Bitbucket.
2. Elestio → **CI/CD → New pipeline → Custom docker-compose**.
3. Source: connect the repo. Target: new Hetzner Medium 2C/4G VM.
4. **Environment Variables** tab: paste values from `.env.example` (minimum: `API_SERVER_KEY`, `GATEWAY_ALLOWED_USERS`, `OPENAI_API_KEY`).
5. **Reverse Proxy** tab: set *Target Port* = `8642`.
6. **Domain Management**: add your custom domain as a CNAME to the Elestio hostname (auto Let's Encrypt).
7. Click **Create CI/CD pipeline**. Subsequent pushes to `main` auto-redeploy.

## Verify

```bash
curl -H "Authorization: Bearer $API_SERVER_KEY" https://<your-domain>/health
# → 200 ok

curl -H "Authorization: Bearer $API_SERVER_KEY" \
     -H "Content-Type: application/json" \
     https://<your-domain>/v1/chat/completions \
     -d '{"model":"gpt-4o","messages":[{"role":"user","content":"ping"}]}'
```

## Access the dashboard (internal)

The dashboard container is not exposed to the public internet. Reach it via SSH tunnel:

```bash
elestio ssh <service-id>                 # or the raw ssh command Elestio prints
# from your laptop:
ssh -L 9119:172.17.0.1:9119 root@<vm>
# open http://localhost:9119
```

## Update config

Edit env vars in the Elestio dashboard → **Restart**. No SSH, no rebuild.

## Upgrade Hermes

Dashboard → **Rebuild & Redeploy**. Data in `storage/hermes/` persists across upgrades (the image is stateless).

## Backups

`storage/hermes/` lives under `/opt/app/` on the VM and is covered by Elestio's Borg backups. Restore via dashboard.

## Local smoke test (optional, before first Elestio deploy)

```bash
cp .env.example .env
# fill: API_SERVER_KEY (openssl rand -hex 32), OPENAI_API_KEY, GATEWAY_ALLOWED_USERS
# TEMP: swap 172.17.0.1 → 127.0.0.1 in docker-compose.yml for local
docker compose config
docker compose up -d
curl -H "Authorization: Bearer $API_SERVER_KEY" http://127.0.0.1:8642/health
docker compose logs -f hermes
docker compose down
# REVERT the 172.17.0.1 change before pushing
```
# hermes
