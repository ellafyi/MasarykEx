#!/usr/bin/env bash
# Load deploy secrets from deploy.env and run kamal.
#
# Usage:
#   bin/deploy.sh                # kamal deploy
#   bin/deploy.sh setup          # first-time bootstrap (run `registry login` first)
#   bin/deploy.sh registry login # authenticate Docker to ghcr.io
#   bin/deploy.sh app logs -f    # any kamal subcommand passes straight through
#
# Secrets live in deploy.env (gitignored). Copy deploy.env.example first:
#   cp deploy.env.example deploy.env && $EDITOR deploy.env
#
# Override the env file with DEPLOY_ENV_FILE=/path/to/file bin/deploy.sh ...
set -euo pipefail

# Run from the repo root so kamal finds config/deploy.yml and .kamal/secrets.
cd "$(dirname "$0")/.."

ENV_FILE="${DEPLOY_ENV_FILE:-deploy.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found." >&2
  echo "       cp deploy.env.example deploy.env  and fill it in." >&2
  exit 1
fi

# Export every assignment in the env file into the environment kamal reads.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Derive DATABASE_URL from POSTGRES_PASSWORD when left blank (keeps the two in sync).
if [[ -z "${DATABASE_URL:-}" && -n "${POSTGRES_PASSWORD:-}" ]]; then
  export DATABASE_URL="postgres://masaryk:${POSTGRES_PASSWORD}@masaryk_ex-db:5432/masaryk_ex_prod"
fi

# Required secrets — fail fast with a clear message rather than a cryptic kamal error.
missing=()
for var in KAMAL_REGISTRY_PASSWORD SECRET_KEY_BASE POSTGRES_PASSWORD DATABASE_URL; do
  [[ -z "${!var:-}" ]] && missing+=("$var")
done
if (( ${#missing[@]} )); then
  printf 'error: missing required secret(s): %s\n' "${missing[*]}" >&2
  printf '       fill them in %s\n' "$ENV_FILE" >&2
  exit 1
fi

# Optional secrets: warn but proceed (empty BOT_TOKEN => headless bot by design).
[[ -z "${BOT_TOKEN:-}" ]] && echo "note: BOT_TOKEN empty — bot will run headless." >&2

exec kamal "${@:-deploy}"
