#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Created .env."
    echo "Edit PROJECT_PATH in .env, then run this script again."
    exit 1
fi

# Use the current host user's IDs so files created in the mounted project
# don't normally become owned by root.
export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"

docker compose build
exec docker compose run --rm copilot
