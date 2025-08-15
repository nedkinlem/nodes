#!/usr/bin/env bash
# Nexus Multi Node Manager
# Підтримка: мульти-ноди, автоперезапуск, логування, діагностика,
# SWAP (8G), перевірка версії CLI, LOOP-режим (кастомний образ),
# DEBUG-LOOP: нескінченний запуск і збереження логів на хості.

set -euo pipefail

NEXUS_IMAGE="nexusxyz/nexus-cli:latest"     # офіційний образ Nexus CLI
LOOP_BASE_IMAGE="debian:bookworm-slim"      # базовий образ для кастомного loop/debug
SWAP_SIZE_GB="${SWAP_SIZE_GB:-8}"
SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS:-30}"
HOST_LOG_ROOT="/var/log/nexus"              # директорія логів на хості

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "\nВстановлення Docker..."
    sudo apt update -y && sudo apt install -y docker.io -y
  fi
}

ok()   { echo -e "$*"; }
warn() { echo -e "$*"; }
err()  { echo -e "$*" >&2; }

container_name_for() { echo "nexus_$1"; }

# -------------------- БАЗОВІ ДІЇ --------------------

install_node() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nЗавантаження образу Nexus CLI..."
  docker pull "$NEXUS_IMAGE"

  echo -e "\nЗапуск ноди у контейнері: $CN"
  docker rm -f "$CN" >/dev/null 2>&1 || true
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    "$NEXUS_IMAGE" start --node-id "$NODE_ID"

  ok "Нода $NODE_ID встановлена і працює у фоні."
  echo "Від'єднання з attach: Ctrl+P, потім Ctrl+Q"
}

update_node() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nОновлення образу Nexus CLI..."
  docker pull "$NEXUS_IMAGE"

  echo -e "\nПерезапуск контейнера $CN..."
  docker rm -f "$CN" >/dev/null 2>&1 || true
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    "$NEXUS_IMAGE" start --node-id "$NODE_ID"

  ok "Ноду $NODE_ID перезапущено."
}

start_node() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nЗапуск або підключення до контейнера $CN..."
  if docker ps -a --format '{{.Names}}' | grep -qx "$CN"; then
    docker start "$CN" >/dev/null 2>&1 || true
    docker attach "$CN" || true
  else
    docker run -it --name "$CN" \
      -e NODE_ID="$NODE_ID" \
      "$NEXUS_IMAGE" start --node-id "$NODE_ID"
  fi
}

show_logs() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nЛоги $CN (Ctrl+C для виходу):\n"
  if docker ps -a --format '{{.Names}}' | grep -qx "$CN"; then
    docker logs -f "$CN"
  else
    err "Контейнер $CN не знайдено."
  fi
}

list_nodes() {
  need_docker
  echo -е "\nСписок контейнерів Nexus:"
  local out
  out=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E '^nexus_') || true
  if [[ -z "${out}" ]]; then
    warn "Немає запущених контейнерів Nexus."
  else
    echo "$out"
  fi
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

delete_node() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nВидалення контейнера $CN..."
  docker rm -f "$CN" >/dev/null 2>&1 || true
  ok "Ноду $NODE_ID видалено."
}

check_version() {
  need_docker
  echo -e "\nВерсія Nexus CLI (з образу):"
  docker run --rm "$NEXUS_IMAGE" --version || warn "Не вдалося отримати версію."
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

make_swap() {
  echo -e "\nПеревірка або створення SWAP (${SWAP_SIZE_GB}G)..."
  if swapon --show | grep -q '^/swapfile'; then
    ok "SWAP уже активний:"
    swapon --show
    return
  fi
  sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  ok "SWAP увімкнено."
  swapon --show
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

diagnose_node() {
  read -rp "Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\nДіагностика $CN:"
  echo -e "\nСтатус:"
  docker ps -a --filter "name=$CN"

  echo -e "\nОстанні 120 рядків логів:"
  docker logs --tail 120 "$CN" 2>/dev/null || warn "Логи недоступні."

  echo -e "\nExit code:"
  docker inspect "$CN" --format='ExitCode: {{.State.ExitCode}}' 2>/dev/null || echo "N/A"

  echo -e "\nПомилка запуску:"
  docker inspect "$CN" --format='Error: {{.State.Error}}' 2>/dev/null || echo "N/A"

  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

# -------------------- LOOP (звичайний) --------------------

setup_loop_mode() {
  read -rp "Введіть ваш NODE ID для loop-режиму: " NODE_ID
  local CN TAG BUILD_DIR
  CN=$(container_name_for "$NODE_ID")
  TAG="nexus-loop-cli-${NODE_ID}"
  BUILD_DIR="${HOME}/nexus_loop_build_${NODE_ID}"

  need_docker
  mkdir -p "$BUILD_DIR"

  cat > "${BUILD_DIR}/loop.sh" <<'EOF'
#!/bin/sh
set -eu
echo "Nexus loop-mode. NODE_ID=${NODE_ID}"
while true; do
  echo "Запуск nexus-cli..."
  /root/.nexus-network/nexus-network start --node-id "${NODE_ID}"
  echo "Завершено. Повторний старт через ${SLEEP_BETWEEN_RUNS}s..."
  sleep "${SLEEP_BETWEEN_RUNS}"
done
EOF
  chmod 0755 "${BUILD_DIR}/loop.sh"

  cat > "${BUILD_DIR}/Dockerfile" <<EOF
FROM ${LOOP_BASE_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://cli.nexus.xyz/ | sh
WORKDIR /root
ENV SLEEP_BETWEEN_RUNS=${SLEEP_BETWEEN_RUNS}
COPY loop.sh /loop.sh
ENTRYPOINT ["/loop.sh"]
EOF

  echo -e "\nЗбір образу ${TAG}..."
  ( cd "$BUILD_DIR" && docker build -t "$TAG" . )

  echo -e "\nВидалення попереднього контейнера (як був)..."
  docker rm -f "$CN" >/dev/null 2>&1 || true

  echo -e "\нЗапуск ${CN} у loop-режимі..."
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    -e SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS}" \
    "$TAG"

  ok "Нода $NODE_ID працює в loop-режимі. Логи: docker logs -f $CN"
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

# -------------------- DEBUG-LOOP (лог-файли) --------------------

setup_debug_loop_mode() {
  read -rp "Введіть ваш NODE ID для debug-loop: " NODE_ID
  local CN TAG BUILD_DIR HOST_LOG_DIR
  CN=$(container_name_for "$NODE_ID")
  TAG="nexus-debug-loop-cli-${NODE_ID}"
  BUILD_DIR="${HOME}/nexus_debug_loop_build_${NODE_ID}"
  HOST_LOG_DIR="${HOST_LOG_ROOT}/${NODE_ID}"

  need_docker
  sudo mkdir -p "$HOST_LOG_DIR"
  sudo chown "$(id -u)":"$(id -g)" "$HOST_LOG_DIR"

  mkdir -p "$BUILD_DIR"

  cat > "${BUILD_DIR}/loop.sh" <<'EOF'
#!/bin/sh
set -eu
LOG_DIR="/logs"
LOG_FILE="${LOG_DIR}/nexus.log"
mkdir -p "$LOG_DIR"
echo "==== $(date -Is) :: DEBUG-LOOP start. NODE_ID=${NODE_ID} ====" >> "$LOG_FILE"
while true; do
  echo "==== $(date -Is) :: run nexus-cli ====" >> "$LOG_FILE"
  /root/.nexus-network/nexus-network start --node-id "${NODE_ID}" >> "$LOG_FILE" 2>&1 || true
  rc=$?
  echo "==== $(date -Is) :: exit code: $rc ====" >> "$LOG_FILE"
  sleep "${SLEEP_BETWEEN_RUNS}"
done
EOF
  chmod 0755 "${BUILD_DIR}/loop.sh"

  cat > "${BUILD_DIR}/Dockerfile" <<EOF
FROM ${LOOP_BASE_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://cli.nexus.xyz/ | sh
WORKDIR /root
ENV SLEEP_BETWEEN_RUNS=${SLEEP_BETWEEN_RUNS}
COPY loop.sh /loop.sh
ENTRYPOINT ["/loop.sh"]
EOF

  echo -e "\nЗбір образу ${TAG}..."
  ( cd "$BUILD_DIR" && docker build -t "$TAG" . )

  echo -e "\nВидалення попереднього контейнера (як був)..."
  docker rm -f "$CN" >/dev/null 2>&1 || true

  echo -e "\nЗапуск ${CN} у DEBUG-LOOP (логи: ${HOST_LOG_DIR}/nexus.log)..."
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    -e SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS}" \
    -v "${HOST_LOG_DIR}:/logs" \
    "$TAG"

  ok "Нода $NODE_ID у debug-loop. Перегляд логів: sudo tail -f ${HOST_LOG_DIR}/nexus.log"
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

tail_debug_logs() {
  read -rp "Введіть ваш NODE ID (debug-loop): " NODE_ID
  local HOST_LOG_DIR="${HOST_LOG_ROOT}/${NODE_ID}"
  if [[ -f "${HOST_LOG_DIR}/nexus.log" ]]; then
    sudo tail -n 200 -f "${HOST_LOG_DIR}/nexus.log"
  else
    err "Файл логів не знайдено: ${HOST_LOG_DIR}/nexus.log"
  fi
}

# -------------------- МЕНЮ --------------------

while true; do
  clear
  echo "==== Nexus Node Manager (мульти-ноди, SWAP, діагностика, loop і debug-loop) ===="
  echo "1) Встановити нову ноду"
  echo "2) Оновити ноду"
  echo "3) Переглянути логи контейнера"
  echo "4) Видалити ноду"
  echo "5) Запустити або підключитися до ноди (attach)"
  echo "6) Список запущених нод"
  echo "7) Перевірити версію CLI"
  echo "8) Увімкнути SWAP (${SWAP_SIZE_GB}G)"
  echo "9) Діагностика ноди"
  echo "10) Loop-режим (кастомний образ)"
  echo "11) Debug-loop (нескінченний запуск і логи у файл)"
  echo "12) Перегляд логів Debug-loop (tail)"
  echo "13) Вийти"
  echo "--------------------------------------------------------------------------"
  read -rp "Оберіть опцію: " choice

  case "$choice" in
    1) install_node ;;
    2) update_node ;;
    3) show_logs ;;
    4) delete_node ;;
    5) start_node ;;
    6) list_nodes ;;
    7) check_version ;;
    8) make_swap ;;
    9) diagnose_node ;;
    10) setup_loop_mode ;;
    11) setup_debug_loop_mode ;;
    12) tail_debug_logs ;;
    13) echo "Вихід..."; exit 0 ;;
    *) err "Невірна опція!"; sleep 2 ;;
  esac
done
