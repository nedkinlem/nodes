#!/bin/bash

NEXUS_IMAGE="nexusxyz/nexus-cli:latest"

function check_docker {
    if ! command -v docker &>/dev/null; then
        echo -e "\n📦 Встановлення Docker..."
        sudo apt update && sudo apt install -y docker.io
    fi
}

function check_screen {
    if ! command -v screen &>/dev/null; then
        echo -e "\n📦 Встановлення screen..."
        sudo apt update && sudo apt install -y screen
    fi
}

function install_node {
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    echo -e "\n📦 Оновлення системи..."
    sudo apt update && sudo apt upgrade -y

    check_docker
    check_screen

    echo -e "\n📥 Завантаження Nexus образу..."
    docker pull $NEXUS_IMAGE

    echo -e "\n🖥️ Створення контейнера для ноди $NODE_ID..."
    docker run -dit --restart unless-stopped --name $CONTAINER_NAME $NEXUS_IMAGE start --node-id $NODE_ID

    echo -e "\n✅ Нода $NODE_ID встановлена та запущена у фоновому режимі!"
}

function update_node {
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    check_docker

    echo -e "\n📥 Оновлення Nexus образу..."
    docker pull $NEXUS_IMAGE

    echo -e "\n🛑 Зупинка старого контейнера $CONTAINER_NAME..."
    docker rm -f $CONTAINER_NAME >/dev/null 2>&1

    echo -e "\n🚀 Запуск оновленої ноди $NODE_ID..."
    docker run -dit --restart unless-stopped --name $CONTAINER_NAME $NEXUS_IMAGE start --node-id $NODE_ID
}

function show_logs {
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    echo -e "\n📄 Останні 50 рядків логів для ноди $NODE_ID..."
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker logs --tail 50 $CONTAINER_NAME
    else
        echo -e "\n❌ Ноду $NODE_ID не знайдено або вона не запущена."
    fi
    echo -e "\nНатисніть Enter для повернення до меню..."
    read
}

function delete_node {
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    echo -e "\n🗑️ Видалення ноди $NODE_ID..."
    docker rm -f $CONTAINER_NAME >/dev/null 2>&1
    echo -e "✅ Ноду $NODE_ID видалено!"
    sleep 2
}

function start_node {
    read -p "🔑 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    echo -e "\n🚀 Запуск ноди $NODE_ID..."
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker start -ai $CONTAINER_NAME
    else
        docker run -dit --restart unless-stopped --name $CONTAINER_NAME $NEXUS_IMAGE start --node-id $NODE_ID
    fi
}

function list_nodes {
    echo -e "\n📋 Список запущених нод:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep nexus_ || echo "❌ Немає запущених контейнерів Nexus"
    echo -e "\nНатисніть Enter для повернення до меню..."
    read
}

function check_version {
    echo -e "\n🔎 Перевірка версії Nexus CLI..."
    docker run --rm $NEXUS_IMAGE --version || echo "⚠️ Неможливо перевірити версію CLI у контейнері."
}

while true; do
    clear
    echo "==== Nexus Node Manager (мульти-ноди з автоперезапуском) ===="
    echo "1) 🟢 Встановити нову ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑️ Видалити ноду"
    echo "5) ▶️ Запустити ноду"
    echo "6) 📋 Список запущених нод"
    echo "7) 🔎 Перевірити версію CLI"
    echo "8) ❌ Вийти"
    echo "------------------------------------------------------"
    read -p "Оберіть опцію: " choice

    case $choice in
        1) install_node ;;
        2) update_node ;;
        3) show_logs ;;
        4) delete_node ;;
        5) start_node ;;
        6) list_nodes ;;
        7) check_version ;;
        8) echo "👋 Вихід..."; exit 0 ;;
        *) echo "❗ Невірна опція!"; sleep 2 ;;
    esac
done
