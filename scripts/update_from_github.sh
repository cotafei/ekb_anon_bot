#!/bin/bash

# ============================================
# Скрипт автоматического обновления EKB Anon Bot с GitHub
# Версия: 3.0 (РАБОЧАЯ - проверено в бою)
# ============================================

# Цвета для красивого вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/cotafei/ekb_anon_bot.git"
TEMP_DIR="ekb_anon_bot_temp"
BACKUP_DIR="backups"
DATE=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}   EKB Anon Bot - Обновление с GitHub   ${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.." || { echo -e "${RED}❌ Ошибка: не могу найти корень проекта${NC}"; exit 1; }
PROJECT_ROOT=$(pwd)
echo -e "${GREEN}✅ Корень проекта: $PROJECT_ROOT${NC}"

# 1. Проверяем наличие git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git не установлен!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Git найден${NC}"
fi

# 2. Проверяем наличие python3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 не установлен!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Python3 найден${NC}"
fi

# 3. Проверяем наличие docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose не установлен!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ docker-compose найден${NC}"
fi

# 4. Создаем резервную копию
echo -e "${YELLOW}📦 Создаю резервную копию...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/pre_update_backup_$DATE.tar.gz"

# Останавливаем бота перед бэкапом
if [ -f "docker/docker-compose.yml" ]; then
    echo -e "${YELLOW}⏸️  Останавливаю бота...${NC}"
    cd docker && docker-compose stop bot 2>/dev/null && cd "$PROJECT_ROOT" || exit
fi

# Создаем бэкап важных данных
if [ -d "data" ] || [ -d "logs" ] || [ -f ".env" ]; then
    tar -czf "$BACKUP_FILE" data/ logs/ .env 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Резервная копия создана: $BACKUP_FILE${NC}"
    else
        echo -e "${YELLOW}⚠️ Не удалось создать бэкап, продолжаем...${NC}"
    fi
fi

# 5. Клонируем свежую версию
echo -e "${YELLOW}📥 Скачиваю последнюю версию с GitHub...${NC}"
rm -rf "$TEMP_DIR" 2>/dev/null
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Ошибка при клонировании репозитория!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Репозиторий скачан${NC}"

# 6. Сохраняем скрипт миграции
if [ -f "src/migrate_db.py" ]; then
    cp src/migrate_db.py /tmp/migrate_db.py.bak
    echo -e "${GREEN}✅ Скрипт миграции сохранен${NC}"
fi

# 7. Обновляем файлы
echo -e "${YELLOW}🔄 Обновляю файлы проекта...${NC}"

# src
rm -rf src 2>/dev/null
cp -r "$TEMP_DIR/src" ./src
if [ -f "/tmp/migrate_db.py.bak" ]; then
    cp /tmp/migrate_db.py.bak src/migrate_db.py
    echo -e "${GREEN}   ✅ Скрипт миграции восстановлен${NC}"
fi

# docker
rm -rf docker 2>/dev/null
cp -r "$TEMP_DIR/docker" ./docker

# scripts
rm -rf scripts 2>/dev/null
cp -r "$TEMP_DIR/scripts" ./scripts
chmod +x scripts/*.sh

# корневые файлы
cp "$TEMP_DIR/requirements.txt" ./requirements.txt
cp "$TEMP_DIR/.env.example" ./.env.example
cp "$TEMP_DIR/CHANGELOG.md" ./CHANGELOG.md 2>/dev/null
cp "$TEMP_DIR/UPDATE.md" ./UPDATE.md 2>/dev/null

echo -e "${GREEN}✅ Файлы обновлены${NC}"

# 8. Проверяем .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Файл .env не найден, создаю из .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}⚠️  ОТРЕДАКТИРУЙТЕ .env файл!${NC}"
    echo -e "${YELLOW}   nano .env${NC}"
    exit 1
fi

# 9. УСТАНАВЛИВАЕМ ЗАВИСИМОСТИ (РАБОЧАЯ КОМАНДА)
echo -e "${YELLOW}📦 Устанавливаю зависимости Python...${NC}"
pip3 install python-dotenv aiogram aiohttp pytz --break-system-packages --ignore-installed

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Ошибка при установке зависимостей!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Зависимости установлены${NC}"

# 10. Запускаем миграцию
echo -e "${YELLOW}🔄 Запускаю миграцию базы данных...${NC}"
cd src
python3 migrate_db.py
MIGRATION_RESULT=$?
cd "$PROJECT_ROOT" || exit

if [ $MIGRATION_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ Миграция БД успешно выполнена${NC}"
else
    echo -e "${RED}❌ Ошибка при миграции БД!${NC}"
    exit 1
fi

# 11. Запускаем бота (РАБОЧАЯ КОМАНДА)
echo -e "${YELLOW}🚀 Запускаю обновленного бота...${NC}"
cd docker
docker-compose up -d --build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Бот успешно обновлен и запущен!${NC}"
else
    echo -e "${RED}❌ Ошибка при запуске бота!${NC}"
    exit 1
fi
cd "$PROJECT_ROOT" || exit

# 12. Убираем временные файлы
rm -rf "$TEMP_DIR" /tmp/migrate_db.py.bak 2>/dev/null

echo ""
echo -e "${GREEN}✅ Обновление завершено!${NC}"
echo -e "${BLUE}📊 Информация:${NC}"
echo "   • Резервная копия: $BACKUP_FILE"
echo "   • Миграция БД: выполнена"
echo "   • Логи: cd docker && docker-compose logs -f"
echo ""
echo -e "${YELLOW}📝 Если хочешь посмотреть логи сразу:${NC}"
echo "   cd docker && docker-compose logs -f"
