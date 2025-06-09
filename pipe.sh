#!/bin/bash

# ========== Встановлення ноди ==========
install_node() {
  echo 'Починаю встановлення ноди...'

  cd $HOME || exit

  if [ -d "$HOME/pop" ]; then
    sudo rm -rf download_cache
    sudo rm -f node_info.json
    sudo rm -f pop
  fi

  sudo apt update -y && sudo apt upgrade -y
  sudo apt install lsof wget make tar screen nano unzip lz4 git jq ufw -y

  ports=(8003)
  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "Помилка: Порт $port зайнятий. Програма не зможе виконатися."
      exit 1
    fi
  done

  while true; do
    read -p "Введіть кількість оперативної пам’яті (RAM, мінімум 4): " RAM
    if [[ "$RAM" =~ ^[0-9]+$ ]] && [ "$RAM" -ge 4 ]; then
      break
    else
      echo "Значення RAM повинно бути числом і не менше 4."
    fi
  done

  while true; do
    read -p "Введіть обсяг місця на диску (мінімум 100ГБ): " DISK_SPACE
    if [[ "$DISK_SPACE" =~ ^[0-9]+$ ]] && [ "$DISK_SPACE" -ge 100 ]; then
      break
    else
      echo "Обсяг диска повинен бути числом і не менше 100ГБ."
    fi
  done

  while true; do
    read -p "Введіть вашу SOL адресу (НЕ ПРИВАТНИЙ КЛЮЧ): " SOLADDRESS
    if [ -n "$SOLADDRESS" ]; then
      break
    else
      echo "Адреса Solana не може бути порожньою."
    fi
  done

  wget -O pop "https://dl.pipecdn.app/v0.2.8/pop"
  chmod +x pop
  mkdir -p download_cache
  sudo ufw allow 8003/tcp

  sudo ./pop  --ram ${RAM}   --max-disk ${DISK_SPACE}  --cache-dir $HOME/download_cache --pubKey ${SOLADDRESS} --signup-by-referral-route 57322f465023c2c0

  sudo tee /etc/systemd/system/pipe.service > /dev/null << EOF
[Unit]
Description=Pipe Node Service
After=network.target
Wants=network-online.target

[Service]
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$HOME
ExecStart=$HOME/pop \
    --ram ${RAM} \
    --max-disk ${DISK_SPACE} \
    --cache-dir $HOME/download_cache \
    --pubKey ${SOLADDRESS}
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pipe-node

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable pipe
  sudo systemctl start pipe

  echo "✅ Нода встановлена та запущена."
}

# ========== Меню ==========
check_logs() {
  echo "Показую останні 40 рядків логів Pipe..."
  journalctl -u pipe -n 40 --output=short | awk '{print $1, $2, $3, substr($0, index($0,$5))}'
}

check_node_status() {
  echo "Перевірка статусу та репутації ноди..."
  ./pop --status
}

display_node_info() {
  echo "Відображення вмісту node_info.json..."
  if [ -f $HOME/node_info.json ]; then
    cat $HOME/node_info.json
  else
    echo "Файл node_info.json не знайдено."
  fi
}

restart_node() {
  echo "Перезапуск Pipe Node..."
  sudo systemctl daemon-reload
  sudo systemctl restart pipe
  echo "Pipe успішно перезапущена."
}

stop_node() {
  echo "Зупинка Pipe Node..."
  sudo systemctl stop pipe
  echo "Pipe успішно зупинена."
}

delete_node() {
  echo "Видалення Pipe Node..."
  sudo systemctl stop pipe
  sudo systemctl disable pipe
  sudo rm -rf download_cache pop node_info.json
  sudo rm -f /etc/systemd/system/pipe.service
  sudo systemctl daemon-reload
  echo "Нода була видалена."
}

exit_script() {
  echo "Вихід..."
  exit 0
}

# Запускаємо встановлення
install_node

# Запускаємо меню
while true; do
  echo -e "\nМеню:"
  echo "1. 📄 Переглянути логи"
  echo "2. 📊 Перевірити статус ноди"
  echo "3. ℹ️ Показати інформацію про ноду"
  echo "4. 🔁 Перезапустити ноду"
  echo "5. ⛔ Зупинити ноду"
  echo "6. 🗑️ Видалити ноду"
  echo "7. 🚪 Вийти зі скрипта"
  read -p "Оберіть пункт меню: " choice

  case $choice in
    1) check_logs ;;
    2) check_node_status ;;
    3) display_node_info ;;
    4) restart_node ;;
    5) stop_node ;;
    6) delete_node ;;
    7) exit_script ;;
    *) echo "Неправильний пункт. Спробуйте ще раз." ;;
  esac
done
