
update_node() {
  delete_node

  if [ -d "$HOME/executor" ] || screen -list | grep -q "\.t3rnnode"; then
    echo 'Папка executor або сесія t3rnnode вже існують. Встановлення неможливе. Оберіть видалити ноду або вийти зі скрипту.'
    return
  fi

  echo 'Починаю оновлення ноди...'

  read -p "Введіть ваш приватний ключ: " PRIVATE_KEY_LOCAL

  download_or_update
}

download_node() {
  if [ -d "$HOME/executor" ] || screen -list | grep -q "\.t3rnnode"; then
    echo 'Папка executor або сесія t3rnnode вже існують. Встановлення неможливе. Оберіть видалити ноду або вийти зі скрипту.'
    return
  fi

  echo 'Починаю встановлення ноди...'

  read -p "Введіть ваш приватний ключ: " PRIVATE_KEY_LOCAL

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install make screen build-essential software-properties-common curl git nano jq -y

  download_or_update
}

download_or_update() {
  cd $HOME

  echo "Оберіть варіант встановлення:"
  echo "1) Встановити останню версію"
  echo "2) Встановити конкретну версію"
  read -p "Введіть номер варіанта (1 або 2): " CHOICE

  if [ "$CHOICE" = "1" ]; then
    sudo curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | \
      grep -Po '"tag_name": "\K.*?(?=")' | \
      xargs -I {} wget https://github.com/t3rn/executor-release/releases/download/{}/executor-linux-{}.tar.gz
    sudo tar -xzf executor-linux-*.tar.gz
    sudo rm -rf executor-linux-*.tar.gz
  elif [ "$CHOICE" = "2" ]; then
    read -p "Введіть номер версії (наприклад, 53 для v0.53.0): " VERSION
    VERSION_FULL="v0.${VERSION}.0"
    sudo wget https://github.com/t3rn/executor-release/releases/download/${VERSION_FULL}/executor-linux-${VERSION_FULL}.tar.gz -O executor-linux.tar.gz
    sudo tar -xzvf executor-linux.tar.gz
    sudo rm -rf executor-linux.tar.gz
  else
    echo "Невірний вибір. Встановлення скасовано."
    return
  fi

  cd executor

  export ENVIRONMENT="testnet"
  export LOG_LEVEL="debug"
  export LOG_PRETTY="false"
  export EXECUTOR_PROCESS_BIDS_ENABLED=true
  export EXECUTOR_PROCESS_ORDERS_ENABLED=true
  export EXECUTOR_PROCESS_CLAIMS_ENABLED=true
  export ENABLED_NETWORKS='l2rn,arbitrum-sepolia,base-sepolia,optimism-sepolia,monad-testnet,blast-sepolia,unichain-sepolia'
  export PRIVATE_KEY_LOCAL="$PRIVATE_KEY_LOCAL"
  export EXECUTOR_PROCESS_BIDS_ENABLED=true
  export EXECUTOR_ENABLE_BATCH_BIDING=true
  export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=false
  export EXECUTOR_PROCESS_ORDERS_API_ENABLED=false
  export EXECUTOR_ENABLE_BATCH_BIDDING=true
  export EXECUTOR_PROCESS_BIDS_BATCH=true
export RPC_ENDPOINTS='{ 
  "l2rn": ["https://t3rn-b2n.blockpi.network/v1/rpc/public", "https://b2n.rpc.caldera.xyz/http"], 
  "arbt": ["https://arb-sepolia.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://arbitrum-sepolia.drpc.org", "https://sepolia-rollup.arbitrum.io/rpc"], 
  "bast": ["https://base-sepolia.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://base-sepolia-rpc.publicnode.com", "https://base-sepolia.drpc.or], 
  "opst": ["https://opt-sepolia.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://sepolia.optimism.io", "https://optimism-sepolia.drpc.org"], 
  "unit": ["https://unichain-sepolia.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://unichain-sepolia.drpc.org", "https://sepolia.unichain.org"], 
  "blst": ["https://blast-sepolia.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://sepolia.blast.io", "https://blast-sepolia.drpc.org"], 
  "mont": ["https://monad-testnet.g.alchemy.com/v2/GZegnJ-NF_-5JIQ-YfpTtEor9qH0BDub", "https://testnet-rpc.monad.xyz"] 
}'
  export EXECUTOR_MAX_L3_GAS_PRICE=1050

  cd $HOME/executor/executor/bin/

  screen -dmS t3rnnode bash -c '
    echo "Початок виконання скрипту в screen-сесії"

    cd $HOME/executor/executor/bin/
    ./executor

    exec bash
  '

  echo "Screen-сесія 't3rnnode' створена і нода запущена..."
}

check_logs() {
  if screen -list | grep -q "\.t3rnnode"; then
    screen -S t3rnnode -X hardcopy -h /tmp/screen_log.txt
    sleep 0.1
    
    if [ -f /tmp/screen_log.txt ]; then
      echo "=== Останні логи t3rnnode ==="
      echo "----------------------------------------"
      tail -n 40 /tmp/screen_log.txt | awk '{print "\033[0;32m" NR "\033[0m: " $0}'
      echo "----------------------------------------"
      echo "Логи успішно виведені (час: $(date '+%H:%M:%S %d.%m.%Y'))"
      rm -f /tmp/screen_log.txt
    else
      echo "Помилка: Не вдалося отримати логи із screen-сесії."
    fi
  else
    echo "Сесія t3rnnode не знайдена."
  fi
}

change_fee() {
    echo 'Починаю зміну комісії...'

    if [ ! -d "$HOME/executor" ]; then
        echo 'Папку executor не знайдено. Встановіть ноду.'
        return
    fi

    session="t3rnnode"

    read -p 'На який газ GWEI ви хочете змінити? (за замовчуванням 1050) ' GWEI_SET

    if screen -list | grep -q "\.${session}"; then
      screen -S "${session}" -p 0 -X stuff "^C"
      sleep 1
      screen -S "${session}" -p 0 -X stuff "export EXECUTOR_MAX_L3_GAS_PRICE=$GWEI_SET\n"
      sleep 1
      screen -S "${session}" -p 0 -X stuff "./executor\n"
      echo 'Комісію було змінено.'
    else
      echo "Сессия ${session} не найдена. Газ не може бути змінений"
      return
    fi
}

stop_node() {
  echo 'Починаю зупинку...'

  if screen -list | grep -q "\.t3rnnode"; then
    screen -S t3rnnode -p 0 -X stuff "^C"
    echo "Нода була зупинена."
  else
    echo "Сесія t3rnnode не знайдена."
  fi
}

auto_restart_node() {
  screen_name="t3rnnode_auto"
  script_path="$HOME/t3rn_restart.sh"

  if screen -list | grep -q "\.$screen_name"; then
    screen -X -S "$screen_name" quit
    echo "Існуючий screen '$screen_name' було зупинено."
  fi

  cat > "$script_path" << 'EOF'
restart_node() {
  echo 'Починаю перезавантаження...'

  session="t3rnnode"
  
  if screen -list | grep -q "\.${session}"; then
    screen -S "${session}" -p 0 -X stuff "^C"
    sleep 1
    screen -S "${session}" -p 0 -X stuff "./executor\n"
    echo "Ноду було перезавантажено."
  else
    echo "Сессия ${session} не найдена."
  fi
}

while true; do
  restart_node
  sleep 7200
done
EOF
  chmod +x "$script_path"

  screen -dmS "$screen_name" bash "$script_path"
  echo "Screen-сессия '$screen_name' создана, нода будет перезапускаться каждые 2 часа."

  (crontab -l 2>/dev/null | grep -v "$script_path"; echo "@reboot screen -dmS $screen_name bash $script_path") | crontab -
  echo "Завдання додано до crontab для автозапуску після перезавантаження сервера."
}

restart_node() {
  echo 'Починаю перезавантаження...'

  session="t3rnnode"
  
  if screen -list | grep -q "\.${session}"; then
    screen -S "${session}" -p 0 -X stuff "^C"
    sleep 1
    screen -S "${session}" -p 0 -X stuff "./executor\n"
    echo "Ноду було перезавантажено."
  else
    echo "Сессия ${session} не найдена."
  fi
}

delete_node() {
  echo 'Починаю видалення ноди...'

  if [ -d "$HOME/executor" ]; then
    sudo rm -rf $HOME/executor
    echo "Папку executor було видалено."
  else
    echo "Папка executor не найдена."
  fi

  if screen -list | grep -q "\.t3rnnode"; then
    sudo screen -X -S t3rnnode quit
    echo "Сесію t3rnnode було закрито."
  else
    echo "Сесія t3rnnode не знайдена."
  fi

  sudo screen -X -S t3rnnode_auto quit

  echo "Ноду було видалено."
}

exit_from_script() {
  exit 0
}

while true; do
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. Встановити ноду"
    echo "2. Перевірити логи ноди"
    echo "3. Змінити комісію"
    echo "4. Зупинити ноду"
    echo "5. Перезапустити ноду"
    echo "6. Автоперезавантаження ноди"
    echo "7. Оновити ноду"
    echo "8. Видалити ноду"
    echo -e "9. Вийти зі скрипту\n"
    read -p "Оберіть пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        check_logs
        ;;
      3)
        change_fee
        ;;
      4)
        stop_node
        ;;
      5)
        restart_node
        ;;
      6)
        auto_restart_node
        ;;
      7)
        update_node
        ;;
      8)
        delete_node
        ;;
      9)
        exit_from_script
        ;;
      *)
        echo "Невірний пункт. Будь ласка, оберіть правильну цифру в меню."
        ;;
    esac
  done
