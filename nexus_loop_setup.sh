#!/usr/bin/env bash
# Nexus CLI loop runner (Docker)
# Usage:
#   ./nexus_loop_setup.sh install     # побудувати образ і запустити loop-контейнер
#   ./nexus_loop_setup.sh start       # старт існуючого контейнера
#   ./nexus_loop_setup.sh stop        # стоп контейнера
#   ./nexus_loop_setup.sh restart     # рестарт контейнера
#   ./nexus_loop_setup.sh logs        # логи контейнера (follow)
#   ./nexus_loop_setup.sh status      # статус контейнера
#   ./nexus_loop_setup.sh remove      # видалити контейнер
#   ./nexus_loop_setup.sh update      # pull базового образу та перебудова
#   ./nexus_loop_setup.sh help        # допомога

set -euo pipefail

# ====== налаштування ======
IMAGE_BASE="nexusxyz/nexus-cli:latest"  # офіційний базовий образ
SLEEP_BETWEEN_RUNS="30"                 # пауза між перезапусками CLI (сек)

# якщо NODE_ID не задано змінною середовища — запитаємо
NODE_ID="${NODE_ID:-}"
if [[ "${1:-}" != "help" && -z "${NODE_ID}" ]]; then
  read -rp "🔑 Введіть ваш NODE ID: " NODE_ID
fi

# імена та шляхи, унікальні для NODE_ID
TAG="nexus-loop-cli-${NODE_ID}"
CONTAINER="nexus_${NODE_ID}"
BUILD_DIR="${HOME}/nexus_loop_build_${NODE_ID}"

# ====== допоміжні ======
need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Встановлюю Docker..."
    sudo apt update -y && sudo apt install -y docker.io
  fi
}

ensure_build_dir() {
  mkdir -p "${BUILD_DIR}"
}

write_loop_files() {
  # loop.sh, який нескінченно запускає nexus-cli
  cat > "${BUILD_DIR}/loop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "🔁 Nexus loop-mode запущено. NODE_ID=${NODE_ID}"
while true; do
  echo "▶️  Старт nexus-cli..."
  ./nexus-network start --node-id "${NODE_ID}"
  echo "🕐 Завершено. Повторний запуск через ${SLEEP_BETWEEN_RUNS}s..."
  sleep "${SLEEP_BETWEEN_RUNS}"
done
EOF
  chmod +x "${BUILD_DIR}/loop.sh"

  # Dockerfile, який додає наш loop.sh
  cat > "${BUILD_DIR}/Dockerfile" <<EOF
FROM ${IMAGE_BASE}
ENV SLEEP_BETWEEN_RUNS=${SLEEP_BETWEEN_RUNS}
COPY loop.sh /loop.sh
RUN chmod +x /loop.sh
CMD ["/loop.sh"]
EOF
}

build_image() {
  echo "🏗  Збираю образ ${TAG}..."
  ( cd "${BUILD_DIR}" && docker build -t "${TAG}" . )
}

pull_base() {
  echo "⬇️  Оновлюю базовий образ ${IMAGE_BASE}..."
  docker pull "${IMAGE_BASE}"
}

stop_container() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}

run_container() {
  echo "🚀 Запускаю контейнер ${CONTAINER} (NODE_ID=${NODE_ID})..."
  docker run -dit \
    --restart unless-stopped \
    --name "${CONTAINER}" \
    -e NODE_ID="${NODE_ID}" \
    "${TAG}"
  echo "✅ Працює. Подивитись логи:  docker logs -f ${CONTAINER}"
}

case "${1:-install}" in
  install)
    need_docker
    ensure_build_dir
    pull_base
    write_loop_files
    build_image
    stop_container
    run_container
    ;;

  start)
    need_docker
    docker start -ai "${CONTAINER}" || {
      echo "❌ Контейнер не знайдено. Запустіть: ./$(basename "$0") install"
      exit 1
    }
    ;;

  stop)
    need_docker
    stop_container
    echo "🛑 Зупинено та видалено контейнер ${CONTAINER}."
    ;;

  restart)
    need_docker
    stop_container
    run_container
    ;;

  logs)
    need_docker
    docker logs -f "${CONTAINER}"
    ;;

  status)
    need_docker
    docker ps -a --filter "name=${CONTAINER}"
    ;;

  remove)
    need_docker
    stop_container
    echo "🧹 Контейнер ${CONTAINER} прибрано. Образ ${TAG} залишено."
    ;;

  update)
    need_docker
    pull_base
    build_image
    echo "🔄 Оновлено базу та перебудовано ${TAG}. За потреби перезапустіть контейнер."
    ;;

  help|-h|--help)
    sed -n '2,40p' "$0"
    ;;

  *)
    echo "❓ Невідома команда '$1'. Використайте: install|start|stop|restart|logs|status|remove|update|help"
    exit 1
    ;;
esac
