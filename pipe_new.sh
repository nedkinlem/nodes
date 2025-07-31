#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📂 Скрипт запущено з папки: $SCRIPT_DIR"

# ========== Встановлення залежностей ==========
install_dependencies() {
  echo "🔎 Перевірка та встановлення залежностей..."

  sudo apt update -y && sudo apt upgrade -y
  sudo apt install lsof wget make tar screen nano unzip lz4 git jq ufw -y

  # Перевірка наявності бібліотеки OpenSSL 3 (libssl.so.3)
  if ! ldconfig -p | grep -q "libssl.so.3"; then
    echo "⚠️ Відсутня бібліотека libssl3. Встановлюю..."
    if sudo apt install libssl3 -y; then
      echo "✅ libssl3 успішно встановлена."
    else
      echo "❌ Не вдалося встановити libssl3. Можливо, у вас стара версія Ubuntu."
      echo "Спробуйте оновити систему або встановити libssl1.1 та створити симлінк."
      sudo apt install libssl1.1 -y && \
      sudo ln -sf /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.3
    fi
  else
    echo "✅ Залежності встановлені."
  fi
}

# ========== Встановлення ноди ==========
install_node() {
  echo '🚀 Починаю встановлення ноди...'

  cd $HOME || exit

  # Очистка попередніх файлів
  if [ -f "$HOME/pop" ]; then
    sudo systemctl stop pipe 2>/dev/null
    sudo systemctl disable pipe 2>/dev/null
    sudo rm -rf download_cache pop node_info.json
    sudo rm -f /etc/systemd/system/pipe.service
    sudo systemctl daemon-reload
  fi

  # Встановлення залежностей
  install_dependencies

  # Перевірка портів
  ports=(8003)
  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "❌ Помилка: Порт $port зайнятий. Завершую встановлення."
      exit 1
    fi
  done

  # Запит ресурсів
  while true; do
    read -p "Введіть кількість оперативної пам’яті (RAM, мінімум 4): " RAM
    if [[ "$RAM" =~ ^[0-9]+$ ]] && [ "$RAM" -ge 4 ]; then
      break
    else
      echo "RAM повинно бути числом і ≥ 4."
    fi
  done

  while true; do
    read -p "Введіть обсяг місця на диску (мінімум 100ГБ): " DISK_SPACE
    if [[ "$DISK_SPACE" =~ ^[0-9]+$ ]] && [ "$DISK_SPACE" -ge 100 ]; then
      break
    else
      echo "Диск повинен бути числом і ≥ 100ГБ."
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

  # Завантаження та встановлення pop
  wget -O pop "https://dl.pipecdn.app/v0.2.8/pop"
  chmod +x pop
  mkdir -p download_cache
  sudo ufw allow 8003/tcp

  # Запуск первинного підключення
  sudo ./pop  --ram ${RAM}   --max-disk ${DISK_SPACE}  --cache-dir $HOME/download_cache --pubKey ${SOLADDRESS} --signup-by-referral-route a8c5923e9548ca3d

  # Створення systemd сервісу
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

  echo "✅ Нода встановлена та запущена!"
}

# ========== Інші функції ==========
check_logs() {
  echo "📜 Показую останні 40 рядків логів..."
  journalctl -u pipe -n 40 --output=short
}

check_node_status() {
  echo "🔎 Перевірка статусу ноди..."
  ./pop --status
}

display_node_info() {
  echo "ℹ️ Інформація про ноду..."
  if [ -f $HOME/node_info.json ]; then
    cat $HOME/node_info.json
  else
    echo "⚠️ Файл node_info.json не знайдено."
  fi
}

restart_node() {
  echo "♻️ Перезапуск ноди..."
  sudo systemctl daemon-reload
  sudo systemctl restart pipe
  echo "✅ Pipe перезапущена."
}

stop_node() {
  echo "⛔ Зупинка ноди..."
  sudo systemctl stop pipe
  echo "✅ Pipe зупинена."
}

delete_node() {
  echo "🗑️ Видалення ноди..."
  sudo systemctl stop pipe 2>/dev/null
  sudo systemctl disable pipe 2>/dev/null
  sudo rm -rf download_cache pop node_info.json
  sudo rm -f /etc/systemd/system/pipe.service
  sudo systemctl daemon-reload
  echo "✅ Нода видалена."
}

show_node_logs() {
  echo "📡 Live логи (Ctrl+C для виходу)..."
  journalctl -u pipe -f
}

exit_script() {
  echo "👋 Вихід..."
  exit 0
}

# ========== Меню ==========
while true; do
  echo -e "\\nМеню:"
  echo "1. 🛠 Встановити або перевстановити ноду"
  echo "2. 📄 Переглянути логи (останні 40 рядків)"
  echo "3. 📊 Перевірити статус ноди"
  echo "4. ℹ️ Показати інформацію про ноду"
  echo "5. 🔁 Перезапустити ноду"
  echo "6. ⛔ Зупинити ноду"
  echo "7. 🗑️ Видалити ноду"
  echo "8. 📘 Переглянути live-логи"
  echo "9. 🚪 Вийти"
  read -p "Оберіть пункт меню: " choice

  case $choice in
    1) install_node ;;
    2) check_logs ;;
    3) check_node_status ;;
    4) display_node_info ;;
    5) restart_node ;;
    6) stop_node ;;
    7) delete_node ;;
    8) show_node_logs ;;
    9) exit_script ;;
    *) echo "❌ Невірний пункт. Спробуйте ще раз." ;;
  esac
done
