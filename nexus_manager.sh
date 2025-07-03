#!/bin/bash

CONTAINER_NAME="nexus"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
SESSION_NAME="nexus"
NODE_ID_FILE="$HOME/.nexus_node_id"

function clear_previous_nexus() {
  echo "[🔍] Перевірка попередніх сесій та контейнерів..."
  screen -S $SESSION_NAME -X quit &> /dev/null
  docker stop $CONTAINER_NAME &> /dev/null
  docker rm $CONTAINER_NAME &> /dev/null
  docker rmi $IMAGE_NAME -f &> /dev/null
}

function save_node_id() {
  read -p "🔑 Введіть ваш Node ID: " NODE_ID
  echo "$NODE_ID" > "$NODE_ID_FILE"
}

function load_node_id() {
  if [[ -f "$NODE_ID_FILE" ]]; then
    NODE_ID=$(cat "$NODE_ID_FILE")
  else
    echo "⚠️ Node ID не знайдено. Будь ласка, встановіть ноду спочатку."
    read -p "Натисніть Enter для повернення в меню..." && return 1
  fi
}

function install_node() {
  clear_previous_nexus
  echo "[✔] Починаємо встановлення..."

  sudo apt update && sudo apt upgrade -y
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh && chmod +x docker_main.sh && ./docker_main.sh
  sudo apt install -y screen

  docker pull $IMAGE_NAME

  save_node_id
  echo "[🚀] Запускаємо ноду..."

  screen -dmS $SESSION_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"

  sleep 15
  echo "[✔] Ноду запущено у сесії screen '$SESSION_NAME'"
  read -p "Натисніть Enter для повернення до меню..."
}

function update_node() {
  load_node_id || return
  echo "[🔁] Оновлюємо образ..."
  docker pull $IMAGE_NAME
  echo "[💥] Зупинка та видалення старого контейнера..."
  docker stop $CONTAINER_NAME &> /dev/null
  docker rm $CONTAINER_NAME &> /dev/null

  echo "[🚀] Запуск нової версії..."
  screen -dmS $SESSION_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"

  echo "[✔] Нода оновлена!"
  read -p "Натисніть Enter для повернення до меню..."
}

function view_logs() {
  if screen -ls | grep -q "$SESSION_NAME"; then
    echo "[📄] Відкриття логів..."
    sleep 1
    screen -r $SESSION_NAME
  else
    echo "❌ Сесія '$SESSION_NAME' не знайдена. Нода наразі не запущена."
    read -p "Натисніть Enter для повернення до меню..."
  fi
}

function start_node() {
  load_node_id || return
  echo "[▶] Запуск ноди з ID: $NODE_ID"
  screen -dmS $SESSION_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"
  echo "[✔] Ноду запущено у фоновій сесії screen '$SESSION_NAME'"
  read -p "Натисніть Enter для повернення до меню..."
}

function delete_node() {
  echo "[⚠] Видалення ноди..."
  screen -S $SESSION_NAME -X quit &> /dev/null
  docker stop $CONTAINER_NAME &> /dev/null
  docker rm $CONTAINER_NAME &> /dev/null
  docker rmi $IMAGE_NAME -f &> /dev/null
  rm -f "$NODE_ID_FILE"
  echo "[🗑] Ноду видалено!"
  read -p "Натисніть Enter для повернення до меню..."
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager ===="
    echo "1) 🟢 Встановити ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑️ Видалити ноду"
    echo "5) ▶️ Запустити ноду"
    echo "6) ❌ Вийти"
    echo "----------------------------"
    read -p "Оберіть опцію: " option
    case $option in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) delete_node ;;
      5) start_node ;;
      6) exit 0 ;;
      *) echo "Невірна опція!"; sleep 1 ;;
    esac
  done
}

main_menu
