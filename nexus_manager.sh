#!/bin/bash

check_and_install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "❌ Docker не встановлено. Встановлюємо..."
    curl -fsSL https://get.docker.com | bash
    sudo usermod -aG docker $USER
    newgrp docker
  fi
}

pause() {
  echo -e "\nНатисніть Enter для повернення до меню..."
  read
}

install_node() {
  clear
  echo "[🟢] Початок встановлення ноди..."
  check_and_install_docker

  echo "[🧹] Перевірка та видалення попередніх сесій..."
  docker rm -f nexus >/dev/null 2>&1
  docker rmi nexusxyz/nexus-cli:latest >/dev/null 2>&1

  echo "[🔧] Оновлення системи..."
  sudo apt update && sudo apt upgrade -y

  echo "[⬇️] Завантаження допоміжного скрипта..."
  wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh && chmod +x docker_main.sh && ./docker_main.sh

  echo "[⬇️] Встановлення screen..."
  sudo apt install -y screen

  echo "[📦] Завантаження Nexus образу..."
  docker pull nexusxyz/nexus-cli:latest

  echo -n "[🆔] Введіть ваш Node ID: "
  read NODE_ID

  echo "[🚀] Запуск ноди..."
  docker run -d --restart unless-stopped --name nexus nexusxyz/nexus-cli:latest start --node-id "$NODE_ID"

  echo "[✅] Нода встановлена та запущена у фоні."
  pause
}

update_node() {
  clear
  echo "[🔄] Оновлення ноди..."
  check_and_install_docker

  echo "[⬇️] Завантаження останнього образу..."
  docker pull nexusxyz/nexus-cli:latest

  echo "[🧹] Видалення старого контейнера..."
  docker rm -f nexus >/dev/null 2>&1

  echo -n "[🆔] Введіть ваш Node ID для повторного запуску: "
  read NODE_ID

  echo "[🚀] Запуск оновленої ноди..."
  docker run -d --restart unless-stopped --name nexus nexusxyz/nexus-cli:latest start --node-id "$NODE_ID"

  echo "[✅] Ноду оновлено та перезапущено."
  pause
}

view_logs() {
  clear
  echo "[📄] Відкриття логів..."

  if docker ps | grep -q nexus; then
    docker logs -f nexus
  else
    echo "❌ Ноду не знайдено або вона не запущена."
    pause
  fi
}

delete_node() {
  clear
  echo "[🗑️] Видалення ноди..."

  docker rm -f nexus >/dev/null 2>&1
  docker rmi nexusxyz/nexus-cli:latest >/dev/null 2>&1

  echo "[✅] Нода та образ успішно видалені."
  pause
}

start_node() {
  clear
  echo "[▶️] Запуск ноди..."

  if docker ps -a | grep -q nexus; then
    docker start nexus
    echo "[✅] Ноду запущено."
  else
    echo "❌ Контейнер 'nexus' не знайдено. Спочатку встановіть ноду."
  fi
  pause
}

main_menu() {
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
    echo -n "Оберіть опцію: "
    read choice

    case $choice in
      1) install_node ;;
      2) update_node ;;
      3) view_logs ;;
      4) delete_node ;;
      5) start_node ;;
      6) exit 0 ;;
      *) echo "Невірний вибір. Спробуйте ще раз."; sleep 2 ;;
    esac
  done
}

main_menu
