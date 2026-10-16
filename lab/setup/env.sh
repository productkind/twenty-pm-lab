# Settings shared by the lab commands. The commands source this file.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$LAB_DIR/.." && pwd)"

# In a codespace, each port has its own private address.
if [ -n "${CODESPACE_NAME:-}" ]; then
  SERVER_URL="https://${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  FRONTEND_URL="https://${CODESPACE_NAME}-3001.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
  SERVER_URL="http://localhost:3000"
  FRONTEND_URL="http://localhost:3001"
fi
export SERVER_URL FRONTEND_URL

# Each copy gets its own encryption key, created the first time.
if [ ! -f "$LAB_DIR/.env" ]; then
  echo "ENCRYPTION_KEY=$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))")" > "$LAB_DIR/.env"
fi
set -a
. "$LAB_DIR/.env"
set +a

export COMPOSE_FILE="$LAB_DIR/docker-compose.yml"
export NX_NO_CLOUD=true
