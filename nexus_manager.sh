#!/bin/bash

show_menu() {
    clear
    echo "==== Nexus Node Manager ===="
    echo "1) 🟢 Встановити ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑️ Видалити ноду"
    echo "5) ▶ Запустити ноду"
    echo "6) ❌ Вийти"
    echo "----------------------------"
    read -p $'\nОберіть опцію: ' option
    case $option in
        1) install_node ;;
        2) update_node ;;
        3) view_logs ;;
        4) remove_node ;;
        5) start_node ;;
        6) exit 0 ;;
        *) read -p $'\n❌ Невірна опція. Натисніть Enter для продовження...' ; show_menu ;;
    esac
}

install_node() {
    echo -e "\n🔍 Перевірка наявних сесій та контейнерів..."
    screen -S nexus -X quit 2>/dev/null
    docker rm -f nexus 2>/dev/null
    docker rmi -f nexusxyz/nexus-cli:latest 2>/dev/null

    echo -e "\n⬆️ Оновлення системи..."
    sudo apt update && sudo apt upgrade -y

    echo -e "\n⬇️ Завантаження Docker скрипта..."
    wget -q -O docker_main.sh https://raw.githubusercontent.com/nedkinlem/nodes/main/Docker.sh && chmod +x docker_main.sh && ./docker_main.sh

    echo -e "\n📦 Встановлення screen..."
    sudo apt install -y screen

    echo -e "\n🐳 Завантаження Nexus образу..."
    docker pull nexusxyz/nexus-cli:latest

    read -p $'\n🔑 Введіть ваш node ID: ' NODE_ID

    echo -e "\n🚀 Запуск ноди..."
    screen -dmS nexus bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $NODE_ID"
    sleep 15
    echo -e "\n✅ Ноду запущено у screen-сесії 'nexus'."
    read -p "Натисніть Enter для повернення до меню..."
    show_menu
}

update_node() {
    echo -e "\n🐳 Оновлення образу Nexus..."
    docker pull nexusxyz/nexus-cli:latest

    echo -e "\n🧹 Зупинка та видалення старого контейнера..."
    docker stop nexus 2>/dev/null
    docker rm nexus 2>/dev/null

    read -p $'\n🔑 Введіть ваш node ID для перезапуску: ' NODE_ID

    echo -e "\n🚀 Запуск ноди з оновленим образом..."
    screen -dmS nexus bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $NODE_ID"
    sleep 15
    echo -e "\n✅ Ноду оновлено та перезапущено."
    read -p "Натисніть Enter для повернення до меню..."
    show_menu
}

view_logs() {
    echo -e "\n📄 Відображення останніх 20 рядків логів..."
    if docker ps | grep -q "nexus"; then
        docker logs --tail 20 -f nexus
    else
        echo -e "\n❌ Ноду не знайдено або вона не запущена."
        read -p "Натисніть Enter для повернення до меню..."
    fi
    show_menu
}

remove_node() {
    echo -e "\n🗑️ Видалення ноди..."
    screen -S nexus -X quit 2>/dev/null
    docker stop nexus 2>/dev/null
    docker rm nexus 2>/dev/null
    docker rmi nexusxyz/nexus-cli:latest 2>/dev/null
    echo -e "\n✅ Ноду повністю видалено."
    read -p "Натисніть Enter для повернення до меню..."
    show_menu
}

start_node() {
    read -p $'\n🔑 Введіть ваш node ID: ' NODE_ID
    echo -e "\n🚀 Запуск ноди..."
    screen -dmS nexus bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $NODE_ID"
    sleep 15
    echo -e "\n✅ Ноду запущено у screen-сесії 'nexus'."
    read -p "Натисніть Enter для повернення до меню..."
    show_menu
}

# Запуск меню
show_menu
