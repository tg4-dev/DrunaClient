#!/usr/bin/env bash
# Raises DrunaServer in Docker on this Mac so a phone in the same Wi-Fi can
# reach it, and points config/development.json at the Mac's current LAN IP.
#
#   scripts/dev_server.sh          start (builds the image when needed)
#   scripts/dev_server.sh stop     stop the containers
#
# The server repository is expected next to this one (../DrunaServer);
# DRUNA_SERVER_DIR overrides that.
set -euo pipefail

client_dir="$(cd "$(dirname "$0")/.." && pwd)"
server_dir="${DRUNA_SERVER_DIR:-$client_dir/../DrunaServer}"
config="$client_dir/config/development.json"
port=22000

if [[ ! -f "$server_dir/docker-compose.yml" ]]; then
  echo "Не нашёл DrunaServer в $server_dir (задай DRUNA_SERVER_DIR)." >&2
  exit 1
fi

compose() { docker compose -f "$server_dir/docker-compose.yml" "$@"; }

if [[ "${1:-}" == "stop" ]]; then
  compose down
  exit 0
fi

# Docker Desktop: start it and wait for the engine.
if ! docker info >/dev/null 2>&1; then
  echo "Запускаю Docker Desktop…"
  open -a Docker
  for _ in $(seq 1 90); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  if ! docker info >/dev/null 2>&1; then
    echo "Docker не запустился за 90 с. Открой Docker Desktop вручную." >&2
    exit 1
  fi
fi

echo "Собираю и поднимаю сервер…"
(cd "$server_dir" && compose up -d --build)

echo -n "Жду сервер"
for _ in $(seq 1 60); do
  if curl -fsS -m 2 "http://localhost:$port/ping/" >/dev/null 2>&1; then
    break
  fi
  echo -n "."
  sleep 1
done
echo
if ! curl -fsS -m 2 "http://localhost:$port/ping/" >/dev/null 2>&1; then
  echo "Сервер не ответил на /ping/. Логи: docker compose -f $server_dir/docker-compose.yml logs app" >&2
  exit 1
fi

# The Mac's address in the Wi-Fi; the router may change it.
ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [[ -z "$ip" ]]; then
  echo "Сервер работает на http://localhost:$port, но Mac не в локальной сети." >&2
  exit 1
fi

url="http://$ip:$port"
if ! curl -fsS -m 2 "$url/ping/" >/dev/null 2>&1; then
  echo "По $url сервер не отвечает. Проверь, что фаервол macOS пускает Docker." >&2
  exit 1
fi

# Point the development config at this address.
sed -i '' -E "s#\"API_BASE_URL\": *\"[^\"]*\"#\"API_BASE_URL\": \"$url\"#" "$config"

cat <<EOF

Сервер доступен в локальной сети: $url
config/development.json → $url

На телефоне (та же Wi-Fi):
  flutter run -d <DEVICE_ID> --dart-define-from-file=config/development.json
При первом запуске iOS спросит доступ к локальной сети — разреши.
Остановить: scripts/dev_server.sh stop
EOF
