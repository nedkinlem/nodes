download_node() {
  echo 'Починаю встановлення ноди...'

  cd $HOME

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install screen nano git curl build-essential make lsof wget jq -y

  if [ -d "$HOME/bot" ]; then
    sudo rm -rf "$HOME/bot"
    sudo rm -rf "$HOME/gaianet"
  fi

  if screen -list | grep -q "gaianetnode"; then
    screen -ls | grep gaianetnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
  sudo apt-get install -y nodejs

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  bash -c "source ~/.bashrc"

  wget -O gaia_install.sh 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh'
  sed -i 's#curl -sSf https://raw\.githubusercontent\.com/WasmEdge/WasmEdge/master/utils/install_v2\.sh | bash -s -- -v $wasmedge_version --ggmlbn=$ggml_bn --tmpdir=$tmp_dir#curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.14.1 --noavx#g' gaia_install.sh
  bash gaia_install.sh
  bash -c "source ~/.bashrc"
}

keep_download() {
  gaianet init --config https://raw.gaianet.ai/qwen2-0.5b-instruct/config.json

  #curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s -- -v 0.13.5 --noavx

  gaianet start


  mkdir bot
  cd bot
  git clone https://github.com/nedkinlem/gaianet
  cd gaianet
  npm i

  gaianet info

  read -p "Введіть ваш Node ID (но перед этим зайдите по ссылке из гайда на сервере): " NEW_ID

  sed -i "s/0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.us.gaianet.network/${NEW_ID}.gaia.domains/g" config.json
  sed -i 's/const CHUNK_SIZE = 5;/const CHUNK_SIZE = 1;/g' bot_gaia.js
  sed -i "s|https://0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.gaia.domains/v1/chat/completions|$(jq -r '.url' config.json)|g" bot_gaia.js
                    
  screen -dmS gaianetnode bash -c '
    echo "Початок виконання скрипта в screen-сесії"

    node bot_gaia.js

    exec bash
  '

  echo "Screen-сесія 'gaianetnode' створена..."
}

check_states() {
  gaianet info
}

check_logs() {
  screen -S gaianetnode -X hardcopy /tmp/screen_log.txt && sleep 0.1 && tail -n 100 /tmp/screen_log.txt && rm /tmp/screen_log.txt
}

update_node() {
  cd $HOME

  gaianet stop
  screen -ls | grep gaianetnode | cut -d. -f1 | awk '{print $1}' | xargs kill

  curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash -s -- --upgrade

  gaianet init --config https://raw.gaianet.ai/qwen2-0.5b-instruct/config.json

  gaianet start

  cd $HOME/bot/gaianet

  sed -i "s|https://0xdbb48499ee7f5db35bcc7f1783f889bacb8d47f6.us.gaianet.network/v1/chat/completions|$(jq -r '.url' config.json)|g" bot_gaia.js

  sed -i 's/.us.gaianet.network/.gaia.domains/g' config.json
  sed -i 's/.us.gaianet.network/.gaia.domains/g' bot_gaia.js 

  screen -dmS gaianetnode bash -c '
    echo "Початок виконання скрипта в screen-сесії"

    node bot_gaia.js

    exec bash
  '

  echo 'Нода оновлена...'
}

link_domain() {
  cd $HOME/bot/gaianet

  if [ ! -f "config.json" ] || [ ! -f "bot_gaia.js" ]; then
      echo "Помилка: config.json или bot_gaia.js не найдены в папке"
      exit 1
  fi

  read -p "Введите API токен: " api_token
  sed -i "/'Authorization':/d" bot_gaia.js
  sed -i "/'user-agent':.*Safari\/537.36',/a \ \ \ \ \ \ 'Authorization': 'Bearer $api_token'," bot_gaia.js
  echo "Токен успішно додано в bot_gaia.js"

  screen -ls | grep gaianetnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  gaianet stop
  gaianet config --domain gaia.domains
  gaianet init

  read -p "Введите ваш домен: " domain_input

  new_domain=${domain_input%.gaia.domains}

  if [ -z "$new_domain" ]; then
      echo "Помилка: ваш домен не може бути порожнім"
      exit 1
  fi

  current_domain=$(grep -o 'https://[^.]*\.gaia\.domains' config.json | sed 's|https://||;s|\.gaia\.domains||')
  if [ ! -z "$current_domain" ]; then
      sed -i "s|https://$current_domain\.gaia\.domains|https://$new_domain.gaia.domains|g" config.json
      echo "config.json: Замінено $current_domain на $new_domain"
  else
      echo "Не знайдено адресу/домен в config.json"
  fi

  current_domain=$(grep -o 'https://[^.]*\.gaia\.domains' bot_gaia.js | sed 's|https://||;s|\.gaia\.domains||')
  if [ ! -z "$current_domain" ]; then
      sed -i "s|https://$current_domain\.gaia\.domains|https://$new_domain.gaia.domains|g" bot_gaia.js
      echo "bot_gaia.js: Замінено $current_domain на $new_domain"
  else
      echo "Не знайдено адресу/домен в bot_gaia.js"
  fi

  gaianet start

  screen -dmS gaianetnode bash -c '
    echo "Початок виконання скрипта в screen-сесії"

    node bot_gaia.js

    exec bash
  '

  echo "Заміна домену виконана!"
}

start_node() {
  gaianet start
}

stop_node() {
  gaianet stop
}

delete_node() {
  cd $HOME
  gaianet stop
  curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/uninstall.sh' | bash
  sudo rm -r bot/
  sudo rm -r gaianet/
  screen -ls | grep gaianetnode | cut -d. -f1 | awk '{print $1}' | xargs kill
}

exit_from_script() {
  exit 0
}

while true; do
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. Встановити ноду"
    echo "2. Продовжити встановлення"
    echo "3. Переглянути дані"
    echo "4. Переглянути логи"
    echo "5. Оновити ноду"
    echo "6. Прив'язати домен"
    echo "7. Запустити ноду"
    echo "8. Зупинити ноду"
    echo "9. Видалити ноду"
    echo -e "10. Вийти зі скрипта\n"
    read -p "Оберіть пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        keep_download
        ;;
      3)
        check_states
        ;;
      4)
        check_logs
        ;;
      5)
        update_node
        ;;
      6)
        link_domain
        ;;
      7)
        start_node
        ;;
      8)
        stop_node
        ;;
      9)
        delete_node
        ;;
      10)
        exit_from_script
        ;;
      *)
        echo "Неправильний пункт. Будь ласка, оберіть правильну цифру в меню."
        ;;
    esac
  done
