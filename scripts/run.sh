#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  EKB Anon Bot - Запуск${NC}"
echo -e "${GREEN}==========================================${NC}"

# Переходим в корневую директорию
cd "$(dirname "$0")/.." || exit

# Создаем директории для данных и логов
mkdir -p data logs backups
echo -e "${GREEN}✅ Директории созданы${NC}"

# Проверяем наличие .env файла
if [ ! -f .env ]; then
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    echo -e "${YELLOW}Скопируйте .env.example в .env и заполните данные:${NC}"
    echo "cp .env.example .env"
    exit 1
fi

# Проверяем Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    exit 1
fi

# Запускаем через docker-compose
echo -e "${YELLOW}🚀 Запуск контейнера...${NC}"
docker-compose -f docker/docker-compose.yml up -d --build

echo -e "${GREEN}✅ Бот запущен!${NC}"
echo -e "${YELLOW}📊 Логи: docker-compose -f docker/docker-compose.yml logs -f${NC}"