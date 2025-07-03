#!/bin/bash

NEXUS_CONTAINER_NAME="nexus"

function install_node {
    echo -e "\n🔍 Перевірка та очищення старих контейнерів і screen-сесій..."
    docker rm -f $NEXUS_CONTAINER_NAME >/dev/null 2>&1
    docker rmi -f nexusxyz/nexus-cli:latest >/dev/null 2>&1
    screen -S nexus -X quit >/dev/null 2>&1

    echo -e "\n📦 Оновлення системи..."
    sudo apt update && sudo apt upgrade -y

    echo -e "\n📦 Встановлення Docker..."
    sudo apt install -y docker.io

    echo -e "\n📦 Встановлення screen..."
    sudo apt install -y screen

    echo -e "\n📥 Завантаження Nexus образу..."
    docker pull nexusxyz/nexus-cli:latest

    echo -e "\n🖥️ Створення screen-сесії..."
    screen -dmS nexus

    read -p "🔑 Введіть ваш node ID: " NODE_ID

    echo -e "\n🚀 Запуск ноди..."
    screen -S nexus -X stuff $"docker run -it --init --name $NEXUS_CONTAINER_NAME nexusxyz/nexus-cli:latest start --node-id $NODE_ID\n"

    echo -e "\n⏳ Зачекайте 15 секунд для запуску..."
    sleep 15
    screen -d nexus
    echo -e "\n✅ Нода встановлена та запущена!"
}

function update_node {
    echo -e "\n📥 Оновлення Nexus образу..."
    docker pull nexusxyz/nexus-cli:latest

    echo -e "\n🛑 Зупинка старого контейнера..."
    docker rm -f $NEXUS_CONTAINER_NAME

    read -p "🔑 Введіть ваш node ID: " NODE_ID

    echo -e "\n🚀 Повторний запуск ноди..."
    docker run -it --init --name $NEXUS_CONTAINER_NAME nexusxyz/nexus-cli:latest start --node-id $NODE_ID
}

function show_logs {
    echo -e "\n📄 Відображення останніх 20 рядків логів..."
    if command -v docker &>/dev/null && docker ps -a | grep -q "$NEXUS_CONTAINER_NAME"; then
        docker logs --tail 20 $NEXUS_CONTAINER_NAME
    else
        echo -e "\n❌ Ноду не знайдено або вона не запущена."
    fi
    echo -e "\nНатисніть Enter для повернення до меню..."
    read
}

function delete_node {
    echo -e "\n🗑️ Видалення ноди..."
    screen -S nexus -X quit >/dev/null 2>&1
    docker rm -f $NEXUS_CONTAINER_NAME
    docker rmi -f nexusxyz/nexus-cli:latest
    echo -e "✅ Ноду видалено!"
    sleep 2
}

function start_node {
    echo -e "\n🚀 Запуск наявної ноди..."
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    docker run -it --init --name $NEXUS_CONTAINER_NAME nexusxyz/nexus-cli:latest start --node-id $NODE_ID
}

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
    read -p "Оберіть опцію: " choice

    case $choice in
        1) install_node ;;
        2) update_node ;;
        3) show_logs ;;
        4) delete_node ;;
        5) start_node ;;
        6) echo "👋 Вихід..."; exit 0 ;;
        *) echo "❗ Невірна опція!"; sleep 2 ;;
    esac
done
