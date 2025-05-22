download_node() {
  echo 'Починаю встановлення...'

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install nano screen cargo unzip build-essential pkg-config libssl-dev git-all protobuf-compiler jq make software-properties-common ca-certificates curl

  if [ -d "$HOME/.nexus" ]; then
    sudo rm -rf "$HOME/.nexus"
  fi

  if screen -list | grep -q "nexusnode"; then
    screen -S nexusnode -X quit
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

  source $HOME/.cargo/env
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  rustup update

  rustup target add riscv32i-unknown-none-elf

  PROTOC_VERSION=29.1
  curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOC_VERSION/protoc-$PROTOC_VERSION-linux-x86_64.zip
  unzip protoc-$PROTOC_VERSION-linux-x86_64.zip -d /usr/local
  export PATH="/usr/local/bin:$PATH"

  mkdir -p $HOME/.config/cli

  screen -dmS nexusnode bash -c '
    echo "Виконується скрипт у screen-сесії"

    sudo curl https://cli.nexus.xyz/ | sh

    exec bash
  '

  echo 'Ноду запущено. Перейдіть до screen-сесії. Якщо захочете повернутися до меню, НЕ ЗАКРИВАЙТЕ ЧЕРЕЗ CTRL+C. Інакше доведеться встановлювати ноду знову.'
}

go_to_screen() {
  screen -r nexusnode
}

check_logs() {
  screen -S nexusnode -X hardcopy /tmp/screen_log.txt && sleep 0.1 && tail -n 100 /tmp/screen_log.txt && rm /tmp/screen_log.txt
}

try_to_fix() {
  session="nexusnode"

  echo "Оберіть пункт:"
  echo "1) Перий спосіб"
  echo "2) Другий спосіб"
  echo "3) Третій спосіб"
  echo "4) Четвертий спосіб"
  read -p "Введіть номер пункту: " choicee

  case $choicee in
      1)
          screen -S "${session}" -p 0 -X stuff "^C"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "rustup target add riscv32i-unknown-none-elf"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "cd $HOME/.nexus/network-api/clients/cli/"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "cargo run --release -- --start --beta"
          echo 'Перевіряйте свої логи.'
          ;;
      2)
          screen -S "${session}" -p 0 -X stuff "^C"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "~/.nexus/network-api/clients/cli/target/release/nexus-network --start"
          echo 'Перевіряйте свої логи.'
          ;;
      3)
          screen -S "${session}" -p 0 -X stuff "^C"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "cd $HOME/.nexus/network-api/clients/cli/"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "rm build.rs"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "rustup target add riscv32i-unknown-none-elf"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "cd $HOME/.nexus/network-api/clients/cli/"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "cargo run --release -- --start --beta"
          echo 'Перевіряйте свої логи.'
          ;;
      4)
          screen -S "${session}" -p 0 -X stuff "sudo apt update -y"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "https://github.com/protocolbuffers/protobuf/releases/download/v29.1/protoc-29.1-linux-x86_64.zip"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "unzip protoc-29.1-linux-x86_64.zip -d /usr/local"
          sleep 1
          screen -S "${session}" -p 0 -X stuff "export PATH="/usr/local/bin:$PATH""
          sleep 1
          screen -S "${session}" -p 0 -X stuff "sudo curl https://cli.nexus.xyz/ | sh"
          echo 'Перевіряйте свої логи.'
          ;;
      *)
          echo "Некоректне введення. Будь ласка, оберіть пункт у меню."
          ;;
  esac
}

make_swap() {
  sudo fallocate -l 10G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

  echo 'Swap було встановлено.'
}

deploy_smart() {
  if ! command -v npm &> /dev/null
  then
      echo "npm не встановлено. Встановлюємо npm 10.8.2..."
      
      if ! command -v nvm &> /dev/null
      then
          echo "Встановлюємо nvm..."
          curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
          export NVM_DIR="$HOME/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      fi
      
      nvm install 20.5.1
      nvm use 20.5.1
      
      npm install -g npm@10.8.2
      echo "npm 10.8.2 успішно встановлено."
  else
      echo "npm вже встановлено."
  fi

  cd $HOME

  if [ -d "$HOME/Nexus_Deploy_Smartcontract" ]; then
    sudo rm -rf "$HOME/Nexus_Deploy_Smartcontract"
  fi

  git clone https://github.com/nedkinlem/Nexus_Deploy_Smartcontract.git

  cd Nexus_Deploy_Smartcontract

  read -s -p "Введіть приватний ключ від гаманця на Nexus (його тут не буде видно): " PRIVATE_KEY
  sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=$PRIVATE_KEY|" .env

  npm install dotenv ethers solc chalk ora cfonts readline-sync

  node index.js
}

make_transaction() {
  if ! command -v npm &> /dev/null
  then
      echo "npm не встановлено. Встановлюємо npm 10.8.2..."
      
      if ! command -v nvm &> /dev/null
      then
          echo "Встановлюємо nvm..."
          curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
          export NVM_DIR="$HOME/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      fi
      
      nvm install 20.5.1
      nvm use 20.5.1
      
      npm install -g npm@10.8.2
      echo "npm 10.8.2 успішно встановлено."
  else
      echo "npm вже встановлено."
  fi

  cd $HOME

  if [ -d "$HOME/Nexus_Make_Transaction" ]; then
    sudo rm -rf "$HOME/Nexus_Make_Transaction"
  fi

  git clone https://github.com/nedkinlem/Nexus_Make_Transaction.git

  cd Nexus_Make_Transaction

  read -s -p "Введіть приватний ключ від гаманця на Nexus (його тут не буде видно): " PRIVATE_KEY
  sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=$PRIVATE_KEY|" .env

  npm install dotenv ethers readline cfonts chalk

  node index.js
}

restart_node() {
  echo 'Починаю перезавантаження...'

  session="nexusnode"
  
  if screen -list | grep -q "\.${session}"; then
    screen -S "${session}" -p 0 -X stuff "^C"
    sleep 1
    screen -S "${session}" -p 0 -X stuff "sudo curl https://cli.nexus.xyz/ | sh\n"
    echo "Ноду було перезавантажено."
  else
    echo "Сесію ${session} не знайдено."
  fi
}

delete_node() {
  screen -S nexusnode -X quit
  sudo rm -r $HOME/.nexus/
  echo 'Ноду було видалено.'
}

exit_from_script() {
  exit 0
}

while true; do
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. Встановити ноду"
    echo "2. Перейти до ноди (вийти CTRL+A D)"
    echo "3. Переглянути логи"
    echo "4. Спробувати виправити помилки"
    echo "5. Встановити SWAP"
    echo "6. Деплой смарт-контракту"
    echo "7. Зробити транзакцію"
    echo "8. Перезапустити ноду"
    echo "9. Видалити ноду"
    echo -e "10. 🚪 Вийти зі скрипта\n"
    read -p "Оберіть пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        go_to_screen
        ;;
      3)
        check_logs
        ;;
      4)
        try_to_fix
        ;;
      5)
        make_swap
        ;;
      6)
        deploy_smart
        ;;
      7)
        make_transaction
        ;;
      8)
        restart_node
        ;;
      9)
        delete_node
        ;;
      10)
        exit_from_script
        ;;
      *)
        echo "Невірний пункт. Будь ласка, оберіть правильну цифру в меню."
        ;;
    esac
  done
