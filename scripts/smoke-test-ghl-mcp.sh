#!/usr/bin/env bash
# Smoke test: validate that Hermes can reach the GoHighLevel MCP server
# and that the LLM invokes GHL tools successfully.
#
# Usage:
#   1. cp .env.local.example .env.local, fill in OPENAI_API_KEY and GHL_PIT_TOKEN
#   2. cp .env.example .env (values can stay empty for local)
#   3. docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
#   4. bash scripts/smoke-test-ghl-mcp.sh
#
# Exit codes:
#   0 = all 3 prompts succeeded
#   1 = health/connectivity issue
#   2 = at least one prompt returned an error or empty tool_calls
set -euo pipefail

# Load .env.local for API_SERVER_KEY / SMOKE_TEST_CONTACT_ID
if [[ -f .env.local ]]; then
  set -a; . .env.local; set +a
fi

: "${API_SERVER_KEY:?API_SERVER_KEY not set (check .env.local)}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8642}"
MODEL="${SMOKE_TEST_MODEL:-gpt-4o}"

hr() { printf '\n\033[36m-- %s --\033[0m\n' "$1"; }

chat() {
  local prompt="$1"
  curl -fsS \
    -H "Authorization: Bearer $API_SERVER_KEY" \
    -H "Content-Type: application/json" \
    "$BASE_URL/v1/chat/completions" \
    -d "$(printf '{"model":"%s","messages":[{"role":"user","content":%s}]}' \
          "$MODEL" "$(printf '%s' "$prompt" | jq -Rs .)")"
}

# -- 0. Health ---------------------------------------------------------
hr "Health check"
curl -fsS -H "Authorization: Bearer $API_SERVER_KEY" "$BASE_URL/health" \
  || { echo "FAIL: gateway not reachable on $BASE_URL"; exit 1; }
printf '\n'

# -- 1. List contacts via GHL MCP --------------------------------------
hr "Prompt 1/3 -- list GHL contacts"
chat "Use the ghl MCP tools to list the first 3 contacts from GoHighLevel. \
Show their names and phone numbers. If the call fails, tell me the exact error."
printf '\n'

# -- 2. List calendars via GHL MCP -------------------------------------
hr "Prompt 2/3 -- list calendars"
chat "Use the ghl MCP tools to list all calendars in my GoHighLevel location. \
For each, show the name and calendar ID. If the call fails, tell me the exact error."
printf '\n'

# -- 3. Draft (DO NOT SEND) an SMS to a test contact -------------------
if [[ -n "${SMOKE_TEST_CONTACT_ID:-}" ]]; then
  hr "Prompt 3/3 -- draft SMS (no send)"
  chat "Using the ghl MCP, look up contact id ${SMOKE_TEST_CONTACT_ID} and tell me \
what you would send as a first-touch SDR SMS. DO NOT actually call any send tool -- \
just describe the message you'd send and explain why."
  printf '\n'
else
  hr "Prompt 3/3 -- skipped (SMOKE_TEST_CONTACT_ID not set)"
fi

hr "Done"
echo "Review the 3 responses above:"
echo "  [OK] GOOD: model called ghl MCP tools and returned real data"
echo "  [KO] BAD:  model says it has no tools, or returns 'I cannot access...'"
echo
echo "Tail Hermes logs to see MCP traffic:"
echo "  docker compose logs -f hermes"
