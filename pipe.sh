

download_node() {
  echo 'Починаю встановлення ноди.'

  cd $HOME

  if [ -d "$HOME/pop" ]; then
    sudo rm -rf download_cache
    sudo rm node_info.json
    sudo rm pop
  fi

  sudo apt install lsof

  ports=(8003)

  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "Помилка: Порт $port занят. Програма не зможе виконатися."
      exit 1
    fi
  done

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install wget make tar screen nano unzip lz4 git jq -y

  while true; do
      read -p "Введите количество выделяемой оперативной памяти (RAM, минимум 4): " RAM
      if [[ "$RAM" =~ ^[0-9]+$ ]] && [ "$RAM" -ge 4 ]; then
          break
      else
          echo "Значення RAM повинно бути числом і не менше 4."
      fi
  done
  
  while true; do
      read -p "Введите количество выделяемого места на диске (минимум 100гб): " DISK_SPACE
      if [[ "$DISK_SPACE" =~ ^[0-9]+$ ]] && [ "$DISK_SPACE" -ge 100 ]; then
          break
      else
          echo "Обсяг диска повинен бути числом і не менше 100ГБ."
      fi
  done
  
  while true; do
      read -p "Введите ваш SOL адрес (НЕ ПРИВАТНЫЙ КЛЮЧ): " SOLADDRESS
      if [ -n "$SOLADDRESS" ]; then
          break
      else
          echo "Адреса Solana не може бути порожньою."
      fi
  done

  wget -O pop "https://dl.pipecdn.app/v0.2.8/pop"
  chmod +x pop

  mkdir download_cache

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
ExecStart=$HOME/pop \\
    --ram ${RAM} \\
    --max-disk ${DISK_SPACE} \\
    --cache-dir $HOME/download_cache \\
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

  sleep 5

  echo 'Нода була встановлена.'
}

check_logs() {
  echo "Показую останні 40 рядків логів Pipe."

  journalctl -u pipe -n 40 --output=short | awk '{print $1, $2, $3, substr($0, index($0,$5))}'
}

check_node_status() {
  local attempts=0
  local max_attempts=10
  local output

  echo "Перевірка статусу та репутації ноди."
  
  cd $HOME
  
  while [ $attempts -lt $max_attempts ]; do
    output=$(./pop --status 2>&1)
    
    echo "$output"
    
    last_two_lines=$(echo "$output" | tail -n 2)
    if [[ "$last_two_lines" != *"Parsed node_info.json"* ]]; then
      break
    fi
    
    attempts=$((attempts + 1))
    echo "Спроба $attempts: Виявлено 'Parsed node_info.json' в останніх двох рядках, повторюємо..."
    sleep 1
  done
  
  if [ $attempts -eq $max_attempts ]; then
    echo "Досягнуто максимальної кількості спроб ($max_attempts)"
  fi
}

display_node_info() {
  echo "Відображення вмісту node_info.json."
  if [ -f $HOME/node_info.json ]; then
    cat $HOME/node_info.json
  else
    echo "Файл node_info.json не знайдено."
  fi
}

restart_node() {
  echo "Перезапуск Pipe Node."

  sudo systemctl daemon-reload
  sudo systemctl enable pipe
  sudo systemctl restart pipe

  echo "Pipe успішно перезапущена."
}

stop_node() {
  echo "Зупинка Pipe Node."

  sudo systemctl stop pipe

  echo "Pipe успішно зупинена."
}

delete_node() {
  echo 'Починаю видалення ноди.'

  sudo rm -rf download_cache
  sudo rm node_info.json
  sudo rm pop

  echo 'Нода була видалена.'
}

exit_from_script() {
  exit 0
}

while true; do
    channel_logo
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. Встановити ноду"
    echo "2. Переглянути логи"
    echo "3. Перевірити статус ноди"
    echo "4. Показати інформацію про ноду"
    echo "5. Перезапустити ноду"
    echo "6. Зупинити ноду"
    echo "7. Видалити ноду"
    echo "8. Вийти зі скрипта"
    read -p "Оберіть пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        check_logs
        ;;
      3)
        check_node_status
        ;;
      4)
        display_node_info
        ;;
      5)
        restart_node
        ;;
      6)
        stop_node
        ;;
      7)
        delete_node
        ;;
      8)
        exit_from_script
        ;;
      *)
        echo "Неправильний пункт. Будь ласка, виберіть правильний номер у меню."
        ;;
    esac
  done
