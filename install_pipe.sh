#!/bin/bash

# Клонування репозиторію
echo "Клоную репозиторій з GitHub..."
git clone https://github.com/nedkinlem/nodes/blob/main/pipe_menu.sh pipe-node || {
  echo "❌ Не вдалося клонувати репозиторій."; exit 1;
}

# Перехід у директорію
cd pipe-node || {
  echo "❌ Не вдалося перейти до папки pipe-node."; exit 1;
}

# Надання прав на виконання
chmod +x pipe_menu.sh

# Запуск меню
echo "✅ Встановлення завершено. Запускаю меню..."
exec ./pipe_menu.sh
