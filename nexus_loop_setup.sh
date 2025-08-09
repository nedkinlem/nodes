#!/usr/bin/env bash
# Nexus CLI loop runner (Variant 1: ENTRYPOINT /loop.sh, no /bin/sh needed)
# Usage:
#   ./nexus_loop_setup.sh install   # build image & start loop container
#   ./nexus_loop_setup.sh restart   # restart container
#   ./nexus_loop_setup.sh start     # start (attach)
#   ./nexus_loop_setup.sh stop      # stop & remove container
#   ./nexus_loop_setup.sh logs      # follow logs
#   ./nexus_loop_setup.sh status    # show container
#   ./nexus_loop_setup.sh update    # pull base & rebuild
#   ./nexus_loop_setup.sh help      # help

set -euo pipefail

IMAGE_BASE="nexusxyz/nexus-cli:latest"
SLEEP_BETWEEN_RUNS="${SLEEP_BETWEEN_RUNS:-30}"

NODE_ID="${NODE_ID:-}"
if [[ "${1:-}" != "help" && -z "${NODE_ID}" ]]; then
  read -rp "🔑 Введіть ваш NODE ID: " NODE_ID
fi

TAG="nexus-loop-cli-${NODE_ID}"
CONTAINER="nexus_${NODE_ID}"
BUILD_DIR="${HOME}/nexus_loop_build_${NODE_ID}"

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Встановлюю Docker..."
    sudo apt update -y && sudo apt install -y docker.io
  fi
}

write_sources() {
  mkdir -p "${BUILD_DIR}"

  # loop.sh виконується напряму як ENTRYPOINT (без /bin/sh у контейнері)
  cat > "${BUILD_DIR}/loop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "🔁 Nexus loop-mode. NODE_ID=${NODE_ID}"
while true; do
  echo "▶️  запуск nexus-cli..."
  # Бінарник присутній у робочій директорії образу
  ./nexus-network start --node-id "${NODE_ID}"
  echo "🕐 завершено. повторний старт через ${SLEEP_BETWEEN_RUNS}s..."
  sleep "${SLEEP_BETWEEN_RUNS}"
done
EOF
  chmod 0755 "${BUILD_DIR}/loop.sh"

  # Dockerfile без RUN/SH — лише COPY і ENTRYPOINT
  cat > "${BUILD_DIR}/Dockerfile" <<EOF
FROM ${IMAGE_BASE}
ENV SLEEP_BETWEEN_RUNS=${SLEEP_BETWEEN_RUNS}
COPY loop.sh /loop.sh
ENTRYPOINT ["/loop.sh"]
EOF
}

pull_base() {
  echo "⬇️  Оновлюю базовий образ ${IMAGE_BASE}..."
  docker pull "${IMAGE_BASE}"
}

build_image() {
  echo "🏗  Збір образу ${TAG}..."
  ( cd "${BUILD_DIR}" && docker build -t "${TAG}" . )
}

stop_container() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}

run_container() {
  echo "🚀 Запуск контейнера ${CONTAINER} (NODE_ID=${NODE_ID})..."
  docker run -dit \
    --restart unless-stopped \
    --name "${CONTAINER}" \
    -e NODE_ID="${NODE_ID}" \
    "${TAG}"
  echo "✅ Працює. Логи:  docker logs -f ${CONTAINER}"
}

case "${1:-install}" in
  install)
    need_docker
    pull_base
    write_sources
    build_image
    stop_container
    run_container
    ;;
  restart)
    need_docker
    stop_container
    run_container
    ;;
  start)
    need_docker
    docker start -ai "${CONTAINER}" || { echo "❌ Немає контейнера. Запустіть: ./$(basename "$0") install"; exit 1; }
    ;;
  stop)
    need_docker
    stop_container
    echo "🛑 Зупинено та видалено ${CONTAINER}."
    ;;
  logs)
    need_docker
    docker logs -f "${CONTAINER}"
    ;;
  status)
    need_docker
    docker ps -a --filter "name=${CONTAINER}"
    ;;
  update)
    need_docker
    pull_base
    build_image
    echo "🔄 Оновлено. За потреби: ./$0 restart"
    ;;
  help|-h|--help)
    sed -n '2,80p' "$0"
    ;;
  *)
    echo "❓ Невідома команда '$1'. Варіанти: install|restart|start|stop|logs|status|update|help"
    exit 1
    ;;
esac
