#!/bin/bash
set -e

if ! command -v docker &>/dev/null; then
  echo "Docker не знайдено — ставимо…"
  sudo apt update
  sudo apt install -y \
    curl \
    ca-certificates \
    apt-transport-https \
    gnupg \
    lsb-release

  if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
      | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  fi

  echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
     https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io

  echo "Docker встановлено"
else
  echo "Docker вже є($(docker --version))"
fi


if ! command -v docker-compose &>/dev/null; then
  echo "Docker Compose не знайдено — ставимо…"
  sudo apt update
  sudo apt install -y wget jq

  COMPOSE_VER=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest \
    | jq -r ".tag_name")

  sudo wget -O /usr/local/bin/docker-compose \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)"
  sudo chmod +x /usr/local/bin/docker-compose

  DOCKER_CLI_PLUGINS=${DOCKER_CLI_PLUGINS:-"$HOME/.docker/cli-plugins"}
  mkdir -p "$DOCKER_CLI_PLUGINS"
  curl -fsSL \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" \
    -o "${DOCKER_CLI_PLUGINS}/docker-compose"
  chmod +x "${DOCKER_CLI_PLUGINS}/docker-compose"

  echo "Docker Compose ${COMPOSE_VER} встановлено"
else
  echo "✔ Docker Compose ($(docker-compose --version))"
fi
