### ДОПРАЦЬОВАНИЙ СКРИПТ MULTI-NODE ###
# TODO: Автоматизує встановлення кількох незалежних нод GAIA
# Кожна нода буде в окремій директорії, на окремому порту, з власним логом і доменом

BASE_PORT=11434
BASE_SCREEN_NAME=gaianode
MAX_NODES=10

function install_node() {
  local index=$1
  local port=$((BASE_PORT + index))
  local dir=$HOME/gaianet_$index
  local screen_name=${BASE_SCREEN_NAME}_$index

  echo "\n>>> Встановлюю ноду #$index на порт $port у директорію $dir..."
  
  mkdir -p $dir
  cd $dir

  curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash -s -- --path $dir --port $port

  echo "alias ${screen_name}_log='screen -r $screen_name'" >> ~/.bashrc
}

function run_node() {
  local index=$1
  local port=$((BASE_PORT + index))
  local dir=$HOME/gaianet_$index
  local screen_name=${BASE_SCREEN_NAME}_$index

  cd $dir
  screen -dmS $screen_name bash -c '
    echo "▶ Запуск gaianet на порту $port..."
    gaianet start --port $port
    exec bash
  '

  echo "🟢 Нода #$index запущена на порті $port у сесії $screen_name"
}

function remove_node() {
  local index=$1
  local port=$((BASE_PORT + index))
  local dir=$HOME/gaianet_$index
  local screen_name=${BASE_SCREEN_NAME}_$index

  echo "❌ Зупиняю і видаляю ноду #$index..."
  screen -S $screen_name -X quit || true
  rm -rf $dir
}

function check_available_resources() {
  echo "\n--- CPU: $(nproc) ядер ---"
  echo "--- RAM:"
  free -h | grep Mem
  echo "--- Зайняті порти:"
  docker ps --format '{{.Ports}}' | grep 114 | wc -l
}

function main_menu() {
  echo -e "\n=== МЕНЮ MULTI-NODE ==="
  echo "1. Встановити нову ноду"
  echo "2. Запустити ноду"
  echo "3. Видалити ноду"
  echo "4. Перевірити ресурси"
  echo "5. Вийти"
  read -p "Оберіть дію: " action

  case $action in
    1)
      read -p "Номер нової ноди (0-$MAX_NODES): " num
      install_node $num
      ;;
    2)
      read -p "Номер ноди для запуску: " num
      run_node $num
      ;;
    3)
      read -p "Номер ноди для видалення: " num
      remove_node $num
      ;;
    4)
      check_available_resources
      ;;
    5)
      echo "🚪 Вихід..."
      exit 0
      ;;
    *)
      echo "⛔ Невідома дія"
      ;;
  esac
}

while true; do
  main_menu
done
