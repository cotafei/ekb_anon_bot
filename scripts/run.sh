#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  EKB Anon Bot v1.1.2 - Запуск${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

cd "$(dirname "$0")/.." || exit 1

mkdir -p data logs backups
echo -e "${GREEN}✅ Директории созданы${NC}"

if [ ! -f .env ]; then
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    echo ""
    echo -e "${YELLOW}Создаю .env из примера...${NC}"
    cp .env.example .env 2>/dev/null
    echo ""
    echo -e "${RED}⚠️  Отредактируйте файл .env и укажите:${NC}"
    echo "   - TOKEN"
    echo "   - CHANNEL_ID"
    echo "   - ADMINS"
    echo ""
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    exit 1
fi

# Запускаем миграцию перед стартом
echo -e "${YELLOW}🔄 Проверяю миграцию БД...${NC}"
cd src && python migrate_db.py && cd ..

echo -e "${YELLOW}🚀 Запуск контейнера...${NC}"
cd docker && docker-compose down 2>/dev/null && docker-compose up -d --build
cd ..

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Бот успешно запущен!${NC}"
    echo ""
    echo -e "${BLUE}📊 Полезные команды:${NC}"
    echo -e "  ${YELLOW}•${NC} Логи: ${GREEN}cd docker && docker-compose logs -f${NC}"
    echo -e "  ${YELLOW}•${NC} Остановка: ${GREEN}scripts/stop.sh${NC}"
    echo -e "  ${YELLOW}•${NC} Бэкап: ${GREEN}scripts/backup.sh${NC}"
    echo -e "  ${YELLOW}•${NC} Обновление: ${GREEN}scripts/update_from_github.sh${NC}"
    echo ""
else
    echo -e "${RED}❌ Ошибка при запуске!${NC}"
    exit 1
fi