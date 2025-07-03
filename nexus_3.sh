#!/bin/bash

CONTAINER_NAME="nexus"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
SESSION_NAME="nexus"
NODE_ID_FILE=".nexus_node_id"

function install_node() {
  echo "[+] Оновлюємо систему..."
  sudo apt update && sudo apt upgrade -y

  echo "[+] Завантажуємо інсталятор Docker..."
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh
  chmod +x docker_main.sh && ./docker_main.sh

  echo "[+] Встановлюємо screen..."
  sudo apt install -y screen

  echo "[+] Завантажуємо образ Nexus..."
  docker pull $IMAGE_NAME

  read -p "🔷 Введіть свій Node ID: " NODE_ID
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ Node ID не може бути порожнім."
    exit 1
  fi
  echo "$NODE_ID" > $NODE_ID_FILE

  echo "[🟢] Запускаємо сесію screen..."
  screen -dmS $SESSION_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"

  echo "[⏳] Чекаємо 15 секунд перед поверненням..."
  sleep 15
  screen -S $SESSION_NAME -X detach

  echo "[✔] Нода встановлена та працює у фоновому режимі."
}

function update_node() {
  if [ ! -f $NODE_ID_FILE ]; then
    echo "❌ Не знайдено ID. Спочатку встановіть ноду."
    return
  fi
  NODE_ID=$(cat $NODE_ID_FILE)

  echo "[+] Оновлюємо Docker-образ..."
  docker pull $IMAGE_NAME

  echo "[🔁] Повертаємось у сесію для зупинки ноди..."
  screen -r $SESSION_NAME

  echo "[!] Після входу в screen натисніть: Ctrl+Q → Ctrl+C"
  echo "⏳ Очікуємо виходу користувача зі screen..."
  read -p "Натисніть Enter коли зупините ноду..."

  echo "[🧹] Видаляємо старий контейнер..."
  docker rm $CONTAINER_NAME

  echo "[🚀] Перезапускаємо ноду..."
  screen -dmS $SESSION_NAME bash -c "docker run -it --init --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID"

  sleep 15
  screen -S $SESSION_NAME -X detach

  echo "[✔] Ноду оновлено та перезапущено."
}

function view_logs() {
  echo "[📄] Підключення до сесії screen..."
  screen -r $SESSION_NAME
}

function remove_node() {
  echo "[⚠] Завершуємо сесію та видаляємо ноду..."
  screen -S $SESSION_NAME -X quit
  docker rm $CONTAINER_NAME
  docker rmi $IMAGE_NAME
  rm -f $NODE_ID_FILE
  echo "[✔] Ноду повністю видалено."
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager ===="
    echo "1) 🟢 Встановити ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) ❌ Видалити ноду"
    echo "5) 🚪 Вийти"
    echo "----------------------------"
    read -p "Оберіть опцію: " choice

    case $choice in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) remove_node ;;
      5) exit 0 ;;
      *) echo "Невірна опція. Спробуйте ще раз." ; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

main_menu
