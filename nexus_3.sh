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
    exit 1
  fi
}

function run_node() {
  echo "[🚀] Запускаємо ноду Nexus з Node ID: $NODE_ID"
  docker run -d \
    --restart unless-stopped \
    --name $CONTAINER_NAME \
    $IMAGE_NAME start --node-id $NODE_ID
  echo "[✔] Нода запущена у фоні!"
}

function view_logs() {
  echo "[📄] Логи ноди (натисни CTRL+C для виходу):"
  docker logs -f $CONTAINER_NAME
}

function remove_node() {
  echo "[⚠] Видалення ноди..."
  docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
  docker rmi $IMAGE_NAME
  echo "[✔] Ноду повністю видалено"
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager (Testnet III) ===="
    echo "Node ID: $NODE_ID"
    echo "------------------------------------------"
    echo "1) 📄 Переглянути логи"
    echo "2) 🔴 Видалити ноду"
    echo "3) ❌ Вийти"
    echo "------------------------------------------"
    read -p "Оберіть опцію: " choice
    case $choice in
      1) view_logs ;;
      2) remove_node ;;
      3) exit 0 ;;
      *) echo "Невірна опція. Спробуйте ще раз."; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

# === Сценарій виконання ===
install_docker
prompt_node_id
run_node
main_menu
