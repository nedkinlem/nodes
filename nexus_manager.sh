#!/bin/bash

CONTAINER_NAME="nexus"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
SCREEN_NAME="nexus"
NODE_ID=""

function check_and_cleanup() {
  echo "[🔍] Перевірка наявних контейнерів та screen-сесій..."

  # Зупинити та видалити контейнер, якщо існує
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "[🧹] Видаляємо існуючий контейнер $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME >/dev/null 2>&1
    docker rm $CONTAINER_NAME >/dev/null 2>&1
  fi

  # Видалити screen-сесію, якщо існує
  if screen -ls | grep -q "\.${SCREEN_NAME}"; then
    echo "[🧹] Закриваємо screen-сесію $SCREEN_NAME..."
    screen -S $SCREEN_NAME -X quit
  fi

  echo "[✔] Очистка завершена."
}

function install_node() {
  check_and_cleanup

  echo "[🔧] Оновлюємо систему..."
  sudo apt update && sudo apt upgrade -y

  echo "[⬇] Завантажуємо скрипт docker_main.sh..."
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh && chmod +x docker_main.sh && ./docker_main.sh

  echo "[📦] Встановлюємо screen..."
  sudo apt install -y screen

  echo "[⬇] Завантажуємо Nexus CLI Docker образ..."
  docker pull $IMAGE_NAME

  echo
  read -p "🔑 Введіть свій Node ID: " NODE_ID
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ Node ID не може бути порожнім."; return
  fi

  echo "[🖥] Створюємо screen-сесію '$SCREEN_NAME'..."
  screen -dmS $SCREEN_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"

  echo "[⏳] Чекаємо 15 секунд, поки контейнер запуститься..."
  sleep 15

  echo "[✔] Нода встановлена у screen-сесії '$SCREEN_NAME'."
}

function update_node() {
  echo "[⬇] Оновлюємо Docker-образ Nexus..."
  docker pull $IMAGE_NAME

  if screen -ls | grep -q "\.${SCREEN_NAME}"; then
    echo "[🔁] Повертаємося до сесії $SCREEN_NAME для перезапуску..."
    screen -r $SCREEN_NAME
    echo
    echo "Після завершення натисніть CTRL+Q, потім CTRL+C щоб зупинити, далі перезапустіть:"
    echo "docker rm $CONTAINER_NAME"
    echo "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"
  else
    echo "❌ Сесія 'nexus' не знайдена. Оновлення неможливе."
  fi
}

function view_logs() {
  echo "[📄] Відкриття логів..."
  if screen -ls | grep -q "\.${SCREEN_NAME}"; then
    screen -r $SCREEN_NAME
  else
    echo "❌ Сесія '$SCREEN_NAME' не знайдена. Нода наразі не запущена."
  fi
}

function remove_node() {
  echo "[🗑] Видалення ноди..."
  if screen -ls | grep -q "\.${SCREEN_NAME}"; then
    screen -S $SCREEN_NAME -X quit
  fi
  docker stop $CONTAINER_NAME >/dev/null 2>&1
  docker rm $CONTAINER_NAME >/dev/null 2>&1
  docker rmi $IMAGE_NAME -f >/dev/null 2>&1
  echo "[✔] Ноду повністю видалено."
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager ===="
    echo "1) 🟢 Встановити ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑️ Видалити ноду"
    echo "5) ❌ Вийти"
    echo "----------------------------"
    read -p "Оберіть опцію: " choice
    case $choice in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) remove_node ;;
      5) exit 0 ;;
      *) echo "Невірна опція. Спробуйте ще раз."; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

main_menu
