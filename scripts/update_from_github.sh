#!/bin/bash

# ============================================
# Скрипт автоматического обновления EKB Anon Bot с GitHub
# Версия: 2.0 (упрощенная, с гарантированной установкой)
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

# 2. Создаем резервную копию
echo -e "${YELLOW}📦 Создаю резервную копию...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/pre_update_backup_$DATE.tar.gz"

# Останавливаем бота перед бэкапом
if [ -f "docker/docker-compose.yml" ]; then
    echo -e "${YELLOW}⏸️  Останавливаю бота...${NC}"
    cd docker && docker-compose stop bot 2>/dev/null && cd "$PROJECT_ROOT" || exit
fi

# Создаем бэкап важных данных
tar -czf "$BACKUP_FILE" data/ logs/ .env 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Резервная копия создана: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}⚠️ Не удалось создать бэкап, продолжаем...${NC}"
fi

# 3. Клонируем свежую версию
echo -e "${YELLOW}📥 Скачиваю последнюю версию с GitHub...${NC}"
rm -rf "$TEMP_DIR" 2>/dev/null
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Ошибка при клонировании репозитория!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Репозиторий скачан${NC}"

# 4. Сохраняем скрипт миграции
if [ -f "src/migrate_db.py" ]; then
    cp src/migrate_db.py /tmp/migrate_db.py.bak
    echo -e "${GREEN}✅ Скрипт миграции сохранен${NC}"
fi

# 5. Обновляем файлы
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

# 6. Проверяем .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Файл .env не найден, создаю из .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}⚠️  ОТРЕДАКТИРУЙТЕ .env файл!${NC}"
    exit 1
fi

# 7. УСТАНАВЛИВАЕМ ЗАВИСИМОСТИ ГЛОБАЛЬНО (через --break-system-packages)
echo -e "${YELLOW}📦 Устанавливаю зависимости Python...${NC}"
pip3 install --upgrade pip --break-system-packages
pip3 install aiogram==3.17.0 python-dotenv==1.0.0 aiohttp==3.9.3 pytz==2024.1 --break-system-packages

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Ошибка при установке зависимостей!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Зависимости установлены${NC}"

# 8. Запускаем миграцию
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

# 9. Запускаем бота
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

# 10. Убираем временные файлы
rm -rf "$TEMP_DIR" /tmp/migrate_db.py.bak 2>/dev/null

echo ""
echo -e "${GREEN}✅ Обновление завершено!${NC}"
echo -e "${BLUE}📊 Информация:${NC}"
echo "   • Резервная копия: $BACKUP_FILE"
echo "   • Миграция БД: выполнена"
echo "   • Логи: cd docker && docker-compose logs -f"
