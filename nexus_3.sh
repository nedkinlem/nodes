#!/bin/bash

CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
NODE_ID=""

function install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "[+] Встановлюємо Docker..."
    sudo apt update
    sudo apt install docker.io -y
    sudo systemctl enable docker --now
  else
    echo "[✔] Docker вже встановлено"
  fi
}

function prompt_node_id() {
  read -p "Введіть свій Node ID: " NODE_ID
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ Node ID не може бути порожнім."
    return 1
  fi
  return 0
}

function run_node() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[ℹ️] Існуючий контейнер знайдено. Видаляю..."
    docker stop $CONTAINER_NAME &>/dev/null
    docker rm $CONTAINER_NAME &>/dev/null
  fi

  prompt_node_id || return

  echo "[🚀] Запускаємо ноду Nexus з Node ID: $NODE_ID"
  docker run -d \
    --restart unless-stopped \
    --name $CONTAINER_NAME \
    --network host \
    $IMAGE_NAME start --node-id $NODE_ID
  echo "[✔] Нода запущена у фоні!"
}

function view_logs() {
  if ! docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[❌] Нода ще не встановлена або була видалена."
    return
  fi
  echo "[📄] Логи ноди (натисни CTRL+C для виходу):"
  docker logs -f $CONTAINER_NAME
}

function remove_node() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[⚠] Зупинка та видалення контейнера..."
    docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
  else
    echo "[ℹ️] Контейнер не знайдено."
  fi
  echo "[🧹] Видалення Docker-образу..."
  docker rmi $IMAGE_NAME
  echo "[✔] Нода та образ повністю видалені."
  NODE_ID=""
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager (Testnet III) ===="
    echo "Node ID: ${NODE_ID:-[не задано]}"
    echo "------------------------------------------"
    echo "1) 🟢 Встановити або перевстановити ноду"
    echo "2) 📄 Переглянути логи"
    echo "3) 🔴 Видалити ноду"
    echo "4) ❌ Вийти"
    echo "------------------------------------------"
    read -p "Оберіть опцію: " choice
    case $choice in
      1) run_node ;;
      2) view_logs ;;
      3) remove_node ;;
      4) exit 0 ;;
      *) echo "Невірна опція. Спробуйте ще раз."; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

# === Сценарій виконання ===
install_docker
main_menu
