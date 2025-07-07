#!/bin/bash

BASE_PORT=11434
BASE_SCREEN_NAME=gaianetnode

function download_node() {
  local index=$1
  local port=$((BASE_PORT + index))
  local dir="$HOME/gaianet_$index"

  echo "\n>>> Встановлення ноди #$index на порт $port у директорію $dir..."

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install screen nano git curl build-essential make lsof wget jq -y

  mkdir -p $dir
  cd $dir

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
  sudo apt-get install -y nodejs

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  bash -c "source ~/.bashrc"

  wget -O gaia_install.sh 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh'
  sed -i 's#curl -sSf https://raw\.githubusercontent\.com/WasmEdge/WasmEdge/master/utils/install_v2\.sh | bash -s -- -v $wasmedge_version --ggmlbn=$ggml_bn --tmpdir=$tmp_dir#curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.14.1 --noavx#g' gaia_install.sh
  bash gaia_install.sh
  bash -c "source ~/.bashrc"
}

function keep_download() {
  local index=$1
  local port=$((BASE_PORT + index))
  local dir="$HOME/gaianet_$index"
  local screen_name=${BASE_SCREEN_NAME}_$index

  cd $dir

  gaianet init --config https://raw.gaianet.ai/qwen2-0.5b-instruct/config.json
  gaianet config --port $port
  gaianet start

  mkdir -p bot
  cd bot
  git clone https://github.com/nedkinlem/gaianet
  cd gaianet
  npm i

  gaianet info

  read -p "Введіть ваш Node ID: " NEW_ID

  sed -i "s/0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.us.gaianet.network/${NEW_ID}.gaia.domains/g" config.json
  sed -i 's/const CHUNK_SIZE = 5;/const CHUNK_SIZE = 1;/g' bot_gaia.js
  sed -i "s|https://0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.gaia.domains/v1/chat/completions|$(jq -r '.url' config.json)|g" bot_gaia.js

  screen -dmS $screen_name bash -c '
    echo "Початок виконання скрипта в screen-сесії"
    node bot_gaia.js
    exec bash
  '

  echo "Screen-сесія '$screen_name' створена..."
}

function check_states() {
  gaianet info
}

function check_logs() {
  local index=$1
  local screen_name=${BASE_SCREEN_NAME}_$index
  screen -S $screen_name -X hardcopy /tmp/screen_log_$index.txt && sleep 0.1 && tail -n 100 /tmp/screen_log_$index.txt && rm /tmp/screen_log_$index.txt
}

function update_node() {
  local index=$1
  local dir="$HOME/gaianet_$index"
  local screen_name=${BASE_SCREEN_NAME}_$index

  cd $dir
  gaianet stop
  screen -S $screen_name -X quit

  curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash -s -- --upgrade

  gaianet init --config https://raw.gaianet.ai/qwen2-0.5b-instruct/config.json
  gaianet start

  cd bot/gaianet

  sed -i "s|https://0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.us.gaianet.network/v1/chat/completions|$(jq -r '.url' config.json)|g" bot_gaia.js
  sed -i 's/.us.gaianet.network/.gaia.domains/g' config.json
  sed -i 's/.us.gaianet.network/.gaia.domains/g' bot_gaia.js

  screen -dmS $screen_name bash -c '
    echo "Початок виконання скрипта в screen-сесії"
    node bot_gaia.js
    exec bash
  '

  echo 'Нода оновлена...'
}

function link_domain() {
  local index=$1
  local dir="$HOME/gaianet_$index"
  local screen_name=${BASE_SCREEN_NAME}_$index

  cd $dir/bot/gaianet

  if [ ! -f "config.json" ] || [ ! -f "bot_gaia.js" ]; then
      echo "Помилка: config.json або bot_gaia.js не знайдені"
      exit 1
  fi

  read -p "Введите API токен: " api_token
  sed -i "/'Authorization':/d" bot_gaia.js
  sed -i "/'user-agent':.*Safari\/537.36',/a \ \ \ \ \ \ 'Authorization': 'Bearer $api_token'," bot_gaia.js

  screen -S $screen_name -X quit
  gaianet stop
  gaianet config --domain gaia.domains
  gaianet init

  read -p "Введите ваш домен: " domain_input
  new_domain=${domain_input%.gaia.domains}

  sed -i "s|https://.*\.gaia\.domains|https://$new_domain.gaia.domains|g" config.json
  sed -i "s|https://.*\.gaia\.domains|https://$new_domain.gaia.domains|g" bot_gaia.js

  gaianet start

  screen -dmS $screen_name bash -c '
    echo "Початок виконання скрипта в screen-сесії"
    node bot_gaia.js
    exec bash
  '

  echo "Заміна домену виконана!"
}

function start_node() {
  gaianet start
}

function stop_node() {
  gaianet stop
}

function delete_node() {
  local index=$1
  local dir="$HOME/gaianet_$index"
  local screen_name=${BASE_SCREEN_NAME}_$index

  cd $dir
  gaianet stop
  curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/uninstall.sh' | bash
  sudo rm -rf $dir
  screen -S $screen_name -X quit
}

function exit_from_script() {
  exit 0
}

while true; do
    echo -e "\n\nМеню:";
    echo "1. Встановити ноду (введіть індекс)"
    echo "2. Продовжити встановлення (введіть індекс)"
    echo "3. Переглянути дані"
    echo "4. Переглянути логи (введіть індекс)"
    echo "5. Оновити ноду (введіть індекс)"
    echo "6. Прив'язати домен (введіть індекс)"
    echo "7. Запустити ноду"
    echo "8. Зупинити ноду"
    echo "9. Видалити ноду (введіть індекс)"
    echo "10. Вийти зі скрипта\n"
    read -p "Оберіть пункт меню: " choice

    case $choice in
      1)
        read -p "Введіть індекс нової ноди: " idx
        download_node $idx
        ;;
      2)
        read -p "Введіть індекс ноди: " idx
        keep_download $idx
        ;;
      3)
        check_states
        ;;
      4)
        read -p "Введіть індекс ноди: " idx
        check_logs $idx
        ;;
      5)
        read -p "Введіть індекс ноди: " idx
        update_node $idx
        ;;
      6)
        read -p "Введіть індекс ноди: " idx
        link_domain $idx
        ;;
      7)
        start_node
        ;;
      8)
        stop_node
        ;;
      9)
        read -p "Введіть індекс ноди: " idx
        delete_node $idx
        ;;
      10)
        exit_from_script
        ;;
      *)
        echo "Неправильний пункт. Будь ласка, оберіть правильну цифру в меню."
        ;;
    esac
  done
