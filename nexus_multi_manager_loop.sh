
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

function make_swap {
    echo -e "\n💾 Створення SWAP (8G)..."
    sudo fallocate -l 8G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo -e "✅ SWAP активовано!"
    sleep 2
}


function setup_loop_mode {
    read -p "🔁 Введіть ваш NODE ID для loop-режиму: " NODE_ID
    WORKDIR=~/nexus_loop_build_$NODE_ID
    CONTAINER_NAME=nexus_$NODE_ID

    echo -e "\n📁 Створення директорії: $WORKDIR"
    mkdir -p "$WORKDIR" && cd "$WORKDIR"

    echo -e "\n📝 Створення loop.sh"
    cat <<EOF > loop.sh
#!/bin/bash
echo "🔁 Nexus loop-режим активовано (ID: \$NODE_ID)"
while true; do
  echo "▶️ Запуск CLI..."
  ./nexus-network start --node-id "\$NODE_ID"
  echo "🕐 Очікування 30 секунд перед повторним запуском..."
  sleep 30
done
EOF

    chmod +x loop.sh

    echo -e "\n📝 Створення Dockerfile"
    cat <<EOF > Dockerfile
FROM nexusxyz/nexus-cli:latest
COPY loop.sh /loop.sh
RUN chmod +x /loop.sh
CMD ["/loop.sh"]
EOF

    echo -e "\n🏗️  Збір Docker-образу: nexus-loop-cli-\$NODE_ID"
    docker build -t nexus-loop-cli-\$NODE_ID .

    echo -e "\n🧹 Видалення попереднього контейнера (якщо був)..."
    docker rm -f \$CONTAINER_NAME >/dev/null 2>&1

    echo -e "\n🚀 Запуск контейнера в loop-режимі..."
    docker run -dit \
      --restart unless-stopped \
      --name \$CONTAINER_NAME \
      -e NODE_ID=\$NODE_ID \
      nexus-loop-cli-\$NODE_ID

    echo -e "\n✅ Нода \$NODE_ID працює в loop-режимі в контейнері \$CONTAINER_NAME"
    echo -e "\nНатисніть Enter для повернення до меню..."
    read
}

function diagnose_node {
    read -p "🔍 Введіть ваш node ID: " NODE_ID
    CONTAINER_NAME="nexus_${NODE_ID}"

    echo -e "\n🧪 Діагностика ноди $NODE_ID:"

    echo -e "\n📤 Статус контейнера:"
    docker ps -a --filter "name=$CONTAINER_NAME"

    echo -e "\n📜 Останні 50 рядків логів:"
    docker logs --tail 50 $CONTAINER_NAME 2>/dev/null || echo "❌ Немає логів або контейнер не знайдено."

    echo -e "\n❗ Exit code:"
    docker inspect $CONTAINER_NAME --format='ExitCode: {{.State.ExitCode}}' 2>/dev/null || echo "N/A"

    echo -e "\n❗ Помилка запуску (якщо була):"
    docker inspect $CONTAINER_NAME --format='Error: {{.State.Error}}' 2>/dev/null || echo "N/A"

    echo -e "\nНатисніть Enter для повернення до меню..."
    read
}

while true; do
    clear
    echo "==== Nexus Node Manager (мульти-ноди з автоперезапуском + SWAP + діагностика) ===="
    echo "1) 🟢 Встановити нову ноду"
    echo "2) 🔄 Оновити ноду"
    echo "3) 📄 Переглянути логи"
    echo "4) 🗑️ Видалити ноду"
    echo "5) ▶️ Запустити ноду"
    echo "6) 📋 Список запущених нод"
    echo "7) 🔎 Перевірити версію CLI"
    echo "8) 💾 Увімкнути SWAP"
    echo "9) 🧪 Діагностика ноди"
    echo "10) 🔁 Встановити ноду в loop-режимі"
    echo "11) ❌ Вийти"
    echo "------------------------------------------------------------------------"
    read -p "Оберіть опцію: " choice

    case $choice in
        1) install_node ;;
        2) update_node ;;
        3) show_logs ;;
        4) delete_node ;;
        5) start_node ;;
        6) list_nodes ;;
        7) check_version ;;
        8) make_swap ;;
        9) diagnose_node ;;
        10) setup_loop_mode ;;
        11) echo "👋 Вихід..."; exit 0 ;;
        *) echo "❗ Невірна опція!"; sleep 2 ;;
    esac
done
