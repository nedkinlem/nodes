#!/bin/bash
# Nexus Multi Node Manager
# ✅ Підтримка: кілька нод (окремі контейнери), автоперезапуск, логування, діагностика,
# ✅ SWAP (8G), перевірка версії CLI, та опціональний LOOP‑режим (кастомний образ).
# Контейнери мають вигляд: nexus_<NODE_ID>

set -euo pipefail

NEXUS_IMAGE="nexusxyz/nexus-cli:latest"       # офіційний CLI-образ
LOOP_BASE_IMAGE="debian:bookworm-slim"        # для loop-режиму (є /bin/sh)
SWAP_SIZE_GB="${SWAP_SIZE_GB:-8}"             # розмір SWAP
SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS:-30}"# пауза між перезапусками у loop-режимі

# --------- helpers ----------
need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "\n📦 Встановлення Docker..."
    sudo apt update -y && sudo apt install -y docker.io -y
  fi
}
ok() { echo -e "✅ $*"; }
warn() { echo -e "⚠️  $*"; }
err() { echo -e "❌ $*" >&2; }

container_name_for() {
  echo "nexus_$1"
}

# --------- core actions ----------
install_node() {
  read -rp "🔑 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")

  need_docker
  echo -e "\n📥 Завантаження образу Nexus CLI..."
  docker pull "$NEXUS_IMAGE"

  echo -e "\n🚀 Запуск ноди у контейнері: $CN"
  docker rm -f "$CN" >/dev/null 2>&1 || true
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    "$NEXUS_IMAGE" start --node-id "$NODE_ID"

  ok "Нода $NODE_ID встановлена і працює у фоні."
  echo "ℹ️  Від'єднання з foreground: Ctrl+P, потім Ctrl+Q"
}

update_node() {
  read -rp "🔑 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")

  need_docker
  echo -e "\n📥 Оновлення образу Nexus CLI..."
  docker pull "$NEXUS_IMAGE"

  echo -e "\n🔄 Перезапуск контейнера $CN на оновленому образі..."
  docker rm -f "$CN" >/dev/null 2>&1 || true
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    "$NEXUS_IMAGE" start --node-id "$NODE_ID"

  ok "Ноду $NODE_ID перезапущено."
}

start_node() {
  read -rp "🔑 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")

  need_docker
  echo -e "\n▶️  Запуск/підключення до контейнера $CN..."
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
  read -rp "🔑 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\n📄 Логи $CN (Ctrl+C для виходу):\n"
  if docker ps -a --format '{{.Names}}' | grep -qx "$CN"; then
    docker logs -f "$CN"
  else
    err "Контейнер $CN не знайдено."
  fi
}

list_nodes() {
  need_docker
  echo -e "\n📋 Список контейнерів Nexus:"
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
  read -rp "🔑 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\n🗑️  Видалення контейнера $CN..."
  docker rm -f "$CN" >/dev/null 2>&1 || true
  ok "Ноду $NODE_ID видалено."
}

check_version() {
  need_docker
  echo -e "\n🔎 Версія Nexus CLI (із образу):"
  docker run --rm "$NEXUS_IMAGE" --version || warn "Не вдалося отримати версію."
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

make_swap() {
  echo -e "\n💾 Перевірка/створення SWAP (${SWAP_SIZE_GB}G)..."
  if swapon --show | grep -q '^/swapfile'; then
    ok "SWAP вже активний:"
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
  read -rp "🔍 Введіть ваш node ID: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  need_docker

  echo -e "\n🧪 Діагностика $CN:"
  echo -e "\n📤 Статус:"
  docker ps -a --filter "name=$CN"

  echo -e "\n📜 Останні 80 рядків логів:"
  docker logs --tail 80 "$CN" 2>/dev/null || warn "Логи недоступні."

  echo -e "\n❗ Exit code:"
  docker inspect "$CN" --format='ExitCode: {{.State.ExitCode}}' 2>/dev/null || echo "N/A"

  echo -e "\n❗ Помилка запуску:"
  docker inspect "$CN" --format='Error: {{.State.Error}}' 2>/dev/null || echo "N/A"

  echo -e "\nℹ️  Від'єднання з attach: Ctrl+P, Ctrl+Q"
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

# --------- loop-mode (кастомний образ) ----------
# будуємо окремий образ, де є /bin/sh; усередині стоїть nexus-cli через офіційний інсталер
setup_loop_mode() {
  read -rp "🔁 Введіть ваш NODE ID для loop‑режиму: " NODE_ID
  local CN; CN=$(container_name_for "$NODE_ID")
  local BUILD_DIR="${HOME}/nexus_loop_build_${NODE_ID}"
  local TAG="nexus-loop-cli-${NODE_ID}"

  need_docker
  mkdir -p "$BUILD_DIR"

  # loop.sh — POSIX sh, щоб не залежати від bash у контейнері
  cat > "${BUILD_DIR}/loop.sh" <<'EOF'
#!/bin/sh
set -eu
echo "🔁 Nexus loop-mode. NODE_ID=${NODE_ID}"
while true; do
  echo "▶️  запуск nexus-cli..."
  /root/.nexus-network/nexus-network start --node-id "${NODE_ID}"
  echo "🕐 завершено. повторний старт через ${SLEEP_BETWEEN_RUNS}s..."
  sleep "${SLEEP_BETWEEN_RUNS}"
done
EOF
  chmod 0755 "${BUILD_DIR}/loop.sh"

  # Dockerfile на базі Debian + офіційний інсталер CLI
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

  echo -e "\n🏗  Збір образу ${TAG}..."
  ( cd "$BUILD_DIR" && docker build -t "$TAG" . )

  echo -e "\n🧹 Видалення попереднього контейнера (як був)..."
  docker rm -f "$CN" >/dev/null 2>&1 || true

  echo -e "\n🚀 Запуск контейнера ${CN} в loop‑режимі..."
  docker run -dit \
    --restart unless-stopped \
    --name "$CN" \
    -e NODE_ID="$NODE_ID" \
    -e SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS}" \
    "$TAG"

  ok "Нода $NODE_ID працює в loop‑режимі. Логи: docker logs -f $CN"
  read -rp $'\nНатисніть Enter для повернення до меню... ' _
}

# --------- menu ----------
while true; do
  clear
  echo "==== Nexus Node Manager (мульти-ноди, автоперезапуск, SWAP, діагностика, loop) ===="
  echo "1) 🟢 Встановити нову ноду (звичайний режим)"
  echo "2) 🔄 Оновити ноду"
  echo "3) 📄 Переглянути логи"
  echo "4) 🗑️  Видалити ноду"
  echo "5) ▶️  Запустити/attach до ноди"
  echo "6) 📋 Список запущених нод"
  echo "7) 🔎 Перевірити версію CLI"
  echo "8) 💾 Увімкнути SWAP (${SWAP_SIZE_GB}G)"
  echo "9) 🧪 Діагностика ноди"
  echo "10) 🔁 Встановити ноду в LOOP‑режимі (кастомний образ)"
  echo "11) ❌ Вийти"
  echo "----------------------------------------------------------------------------"
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
    11) echo "👋 Вихід..."; exit 0 ;;
    *) err "Невірна опція!"; sleep 2 ;;
  esac
done
