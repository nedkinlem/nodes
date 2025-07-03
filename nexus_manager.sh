#!/bin/bash

CONTAINER_NAME="nexus"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
NODE_ID_FILE="$HOME/.nexus_node_id"

function install_node() {
  echo "🔍 Перевірка старих контейнерів та сесій..."

  docker stop $CONTAINER_NAME &>/dev/null
  docker rm $CONTAINER_NAME &>/dev/null
  docker rmi $IMAGE_NAME -f &>/dev/null

  echo "📦 Оновлюємо систему..."
  sudo apt update && sudo apt upgrade -y

  echo "🐳 Встановлюємо Docker..."
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh
  chmod +x docker_main.sh && ./docker_main.sh

  echo "⬇️ Завантажуємо образ ноди..."
  docker pull $IMAGE_NAME

  echo "🆔 Введіть Node ID:"
  read NODE_ID

  if [[ -z "$NODE_ID" ]]; then
    echo "❌ Node ID не може бути порожнім"
    exit 1
  fi

  echo "$NODE_ID" > $NODE_ID_FILE

  echo "🚀 Запускаємо ноду..."
  docker run -dit --init --restart=unless-stopped \
    --name $CONTAINER_NAME \
    $IMAGE_NAME start --node-id $NODE_ID

  echo "✅ Ноду запущено у фоновому режимі!"
  sleep 2
}

function update_node() {
  if [ ! -f "$NODE_ID_FILE" ]; then
    echo "❌ Node ID не збережено. Спочатку встановіть ноду."
    read -p "Натисніть Enter для повернення до меню..."
    return
  fi

  NODE_ID=$(cat $NODE_ID_FILE)

  echo "🔄 Оновлюємо образ..."
  docker pull $IMAGE_NAME

  echo "🧹 Видаляємо старий контейнер..."
  docker stop $CONTAINER_NAME &>/dev/null
  docker rm $CONTAINER_NAME &>/dev/null

  echo "🚀 Перезапуск ноди з ID: $NODE_ID..."
  docker run -dit --init --restart=unless-stopped \
    --name $CONTAINER_NAME \
    $IMAGE_NAME start --node-id $NODE_ID

  echo "✅ Ноду оновлено та перезапущено!"
  sleep 2
}

function view_logs() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "📄 Логи (натисніть Ctrl+C для виходу):"
    docker logs -f $CONTAINER_NAME
  else
    echo "❌ Ноду не знайдено або вона не запущена."
    read -p "Натисніть Enter для повернення до меню..."
  fi
}

function remove_node() {
  echo "🧹 Зупиняємо та видаляємо ноду..."
  docker stop $CONTAINER_NAME &>/dev/null
  docker rm $CONTAINER_NAME &>/dev/null
  docker rmi $IMAGE_NAME -f &>/dev/null
  rm -f $NODE_ID_FILE
  echo "✅ Ноду повністю видалено"
  sleep 2
}

function start_node() {
  if [ ! -f "$NODE_ID_FILE" ]; then
    echo "❌ Node ID не знайдено. Спочатку встановіть ноду."
    read -p "Натисніть Enter для повернення до меню..."
    return
  fi

  NODE_ID=$(cat $NODE_ID_FILE)

  echo "🚀 Запускаємо ноду..."
  docker run -dit --init --restart=unless-stopped \
    --name $CONTAINER_NAME \
    $IMAGE_NAME start --node-id $NODE_ID

  echo "✅ Ноду запущено!"
  sleep 2
}

function main_menu() {
  while true; do
    clear
    echo "==== Nexus Node Manager ===="
    echo "1) 🟢 Встановити ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑 Видалити ноду"
    echo "5) ▶️ Запустити ноду"
    echo "6) ❌ Вийти"
    echo "----------------------------"
    read -p "Оберіть опцію: " choice
    case $choice in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) remove_node ;;
      5) start_node ;;
      6) exit 0 ;;
      *) echo "❗️ Невірна опція" ; sleep 1 ;;
    esac
  done
}

main_menu
