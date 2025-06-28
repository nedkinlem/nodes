#!/bin/bash

NODE_ID="9212846"
CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexusxyz/nexus-cli:latest"

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

function run_node() {
  echo "[🚀] Запускаємо ноду Nexus з Node ID: $NODE_ID"
  docker run -d \
    --restart unless-stopped \
    --name $CONTAINER_NAME \
    $IMAGE_NAME start --node-id $NODE_ID
  echo "[✔] Ноду запущено у фоні. Для логів обери відповідний пункт."
}

function view_logs() {
  echo "[📄] Вивід логів (натисни CTRL+C для виходу):"
  docker logs -f $CONTAINER_NAME
}

function remove_node() {
  echo "[⚠] Зупинка та видалення контейнера..."
  docker stop $CONTAINER_NAME
  docker rm $CONTAINER_NAME
  echo "[✔] Контейнер видалено"

  echo "[⚠] Видалення образу Docker (необов’язково)..."
  docker rmi $IMAGE_NAME
  echo "[✔] Образ видалено"
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager (Testnet III) ===="
    echo "Node ID: $NODE_ID"
    echo "------------------------------------------"
    echo "1) 🟢 Встановити та запустити ноду"
    echo "2) 📄 Переглянути логи"
    echo "3) 🔴 Зупинити та видалити ноду"
    echo "4) ❌ Вийти"
    echo "------------------------------------------"
    read -p "Введіть номер опції: " choice
    case $choice in
      1) install_docker && run_node ;;
      2) view_logs ;;
      3) remove_node ;;
      4) exit 0 ;;
      *) echo "Невірний вибір. Спробуй ще раз."; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

main_menu
