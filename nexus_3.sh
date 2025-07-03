#!/bin/bash

function cleanup_environment() {
  echo "[🔍] Перевірка наявності активних screen-сесій..."
  for s in $(screen -ls | grep nexus | awk -F. '{print $1}' | awk '{print $1}'); do
    echo "⛔ Закриваємо сесію: $s"
    screen -S $s -X quit
  done

  echo "[🔍] Перевірка запущених Docker-контейнерів Nexus..."
  if docker ps -a --format '{{.Names}}' | grep -q "^nexus$"; then
    echo "🗑️ Видаляємо контейнер 'nexus'"
    docker stop nexus && docker rm nexus
  fi

  echo "[🔍] Перевірка наявності образу nexus-cli..."
  if docker images | grep -q nexusxyz/nexus-cli; then
    echo "🗑️ Видаляємо образ nexusxyz/nexus-cli:latest"
    docker rmi nexusxyz/nexus-cli:latest
  fi
}

function install_node() {
  cleanup_environment

  echo "[🧱] Оновлення системи та встановлення залежностей..."
  sudo apt update && sudo apt upgrade -y

  echo "[📦] Завантаження скрипта docker_main.sh..."
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh && chmod +x docker_main.sh && ./docker_main.sh

  echo "[🖥️] Встановлюємо screen..."
  sudo apt install -y screen

  echo "[🐳] Завантажуємо Docker-образ Nexus..."
  docker pull nexusxyz/nexus-cli:latest

  echo "[🔐] Введіть свій Node ID:"
  read NODE_ID
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ Node ID не може бути порожнім."
    exit 1
  fi

  echo "[🧠] Створюємо нову screen-сесію 'nexus'..."
  screen -dmS nexus bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $NODE_ID"

  echo "[⏳] Очікуємо 15 секунд запуску..."
  sleep 15

  echo "[✅] Ноду запущено у фоновому режимі!"
}

function update_node() {
  echo "[⬇️] Завантаження останнього образу..."
  docker pull nexusxyz/nexus-cli:latest

  echo "[🔁] Вхід до screen-сесії..."
  screen -r nexus
  echo "[ℹ️] Всередині сесії натисніть: Ctrl+Q → Ctrl+C"
  echo "[🧹] Далі введіть: docker rm nexus"
  echo "[🚀] Потім: docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id ВАШ_ID"
}

function view_logs() {
  echo "[📄] Відкриття логів..."
  screen -r nexus
}

function delete_node() {
  echo "[⚠] Видалення ноди..."
  screen -S nexus -X quit
  docker rm nexus
  docker rmi nexusxyz/nexus-cli:latest
  echo "[✔] Ноду видалено повністю."
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
    read -p "Оберіть опцію: " option
    case $option in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) delete_node ;;
      5) exit 0 ;;
      *) echo "❌ Невірна опція!" ; sleep 1 ;;
    esac
    read -p "Натисніть Enter для повернення до меню..."
  done
}

main_menu
