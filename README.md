# Hermes Agent on Elestio

Self-hosted [Hermes Agent](https://hermes-agent.nousresearch.com/) gateway (OpenAI-compatible API) behind Elestio's managed HTTPS.

## Deploy

1. Push this repo to GitHub / GitLab / Bitbucket.
2. Elestio -> **CI/CD -> New pipeline -> Custom docker-compose**.
3. Source: connect the repo. Target: new Hetzner Medium 2C/4G VM.
4. **Environment Variables** tab: paste values from `.env.example` (minimum: `API_SERVER_KEY`, `GATEWAY_ALLOWED_USERS`, `OPENAI_API_KEY`).
5. **Reverse Proxy** tab: set *Target Port* = `8642`.
6. **Domain Management**: add your custom domain as a CNAME to the Elestio hostname (auto Let's Encrypt).
7. Click **Create CI/CD pipeline**. Subsequent pushes to `main` auto-redeploy.

## Verify

```bash
curl -H "Authorization: Bearer $API_SERVER_KEY" https://<your-domain>/health
# -> 200 ok

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

Edit env vars in the Elestio dashboard -> **Restart**. No SSH, no rebuild.

## Upgrade Hermes

Dashboard -> **Rebuild & Redeploy**. Data in `storage/hermes/` persists across upgrades (the image is stateless).

## Backups

`storage/hermes/` lives under `/opt/app/` on the VM and is covered by Elestio's Borg backups. Restore via dashboard.

## Local smoke test -- validate GHL MCP before deploying

Purpose: confirm that Hermes can reach the official GoHighLevel MCP server and that the LLM invokes GHL tools -- the riskiest assumption of the SDR architecture, validated in ~20 min without touching Elestio.

```bash
# 1. Prep env files
cp .env.example .env                    # values can stay empty for local run
cp .env.local.example .env.local        # fill OPENAI_API_KEY + GHL_PIT_TOKEN

# 2. Boot Hermes with the local override (binds to 127.0.0.1)
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
docker compose logs -f hermes           # in another terminal; watch for MCP load

# 3. Run the smoke test (3 prompts: list contacts, list calendars, draft SMS)
bash scripts/smoke-test-ghl-mcp.sh

# 4. Open the dashboard to inspect sessions / memory / tool calls
#    http://127.0.0.1:9119

# 5. Teardown
docker compose -f docker-compose.yml -f docker-compose.local.yml down
```

What to look for in the responses:
- **GOOD**: the model names specific contacts/calendars with real IDs from your GHL sub-account
- **BAD**: "I don't have access to any tools" -- means the MCP server didn't register (check `hermes` logs for MCP errors, verify `GHL_PIT_TOKEN` scopes)

Only proceed to Step 2 (skill scaffolding + Elestio deploy) after all 3 prompts return real GHL data.
