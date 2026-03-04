#!/bin/bash

# ============================================
# ADMIN CONSOLE - EKB Anon Bot
# Версия: 1.0
# ============================================

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")/.." || exit 1
PROJECT_ROOT=$(pwd)

# Функция выполнения SQL
exec_sql() {
    docker exec -i ekb-anon-bot sqlite3 /app/data/anon_ekb.db "$1" 2>/dev/null
}

# Функция проверки статуса
check_status() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📊 СТАТУС БОТА${NC}"
    echo -e "${CYAN}────────────────────────────────────────${NC}"
    
    if docker ps | grep -q ekb-anon-bot; then
        echo -e "   ${GREEN}✅ БОТ РАБОТАЕТ${NC}"
        
        CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" ekb-anon-bot 2>/dev/null)
        MEM=$(docker stats --no-stream --format "{{.MemUsage}}" ekb-anon-bot 2>/dev/null)
        echo -e "   💻 CPU: $CPU"
        echo -e "   🐏 RAM: $MEM"
        
        UPTIME=$(docker inspect --format='{{.State.StartedAt}}' ekb-anon-bot | xargs date -d 2>/dev/null)
        echo -e "   ⏰ Запущен: $UPTIME"
    else
        echo -e "   ${RED}❌ БОТ ОСТАНОВЛЕН${NC}"
    fi
    
    # Статистика БД
    TOTAL_USERS=$(exec_sql "SELECT COUNT(*) FROM users;")
    TOTAL_POSTS=$(exec_sql "SELECT COUNT(*) FROM posts;")
    PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
    BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;")
    
    echo -e "\n   👥 Пользователей: $TOTAL_USERS"
    echo -e "   📝 Постов: $TOTAL_POSTS"
    echo -e "   ⏳ На модерации: $PENDING"
    echo -e "   🔴 Забанено: $BANNED"
}

# Функция просмотра логов
show_logs() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📋 ЛОГИ БОТА${NC}"
    echo -e "${CYAN}────────────────────────────────────────${NC}"
    
    echo -e "${YELLOW}1) Последние 50 строк${NC}"
    echo -e "${YELLOW}2) Логи за сегодня${NC}"
    echo -e "${YELLOW}3) Только ошибки${NC}"
    echo -e "${YELLOW}4) Логи в реальном времени${NC}"
    echo -e "${YELLOW}0) Назад${NC}"
    echo ""
    read -p "Выбери: " log_choice
    
    case $log_choice in
        1) cd docker && docker-compose logs --tail=50 --no-log-prefix ;;
        2) cd docker && docker-compose logs --since="$(date +%Y-%m-%d)" --no-log-prefix ;;
        3) cd docker && docker-compose logs --tail=200 --no-log-prefix 2>&1 | grep -i error ;;
        4) cd docker && docker-compose logs -f ;;
        *) return ;;
    esac
    cd "$PROJECT_ROOT" || exit
}

# Функция управления пользователями
user_management() {
    while true; do
        clear
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${WHITE}👥 УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ${NC}"
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        echo -e "${GREEN}1)  Список пользователей${NC}"
        echo -e "${GREEN}2)  🔍 Поиск пользователя${NC}"
        echo -e "${GREEN}3)  ⛔ Забанить${NC}"
        echo -e "${GREEN}4)  ✅ Разбанить${NC}"
        echo -e "${GREEN}5)  📋 Список забаненных${NC}"
        echo -e "${GREEN}6)  💰 Изменить монеты${NC}"
        echo -e "${GREEN}7)  🏆 Топ по монетам${NC}"
        echo -e "${GREEN}8)  📊 Статистика пользователей${NC}"
        echo -e "${GREEN}9)  🗑️ Удалить пользователя${NC}"
        echo -e "${GREEN}10) 📧 Сменить username${NC}"
        echo -e "${GREEN}11) 🔄 Сбросить статистику${NC}"
        echo -e "${GREEN}0)  Назад${NC}"
        echo ""
        read -p "Выбери: " user_choice
        
        case $user_choice in
            1) 
                echo -e "\n${CYAN}👥 Последние 30 пользователей:${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    COALESCE(u.username, '—') as username,
                    COALESCE(up.points, 0) as points,
                    u.posts_count,
                    CASE WHEN u.is_banned = 1 THEN '🔴' ELSE '✅' END as status
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                ORDER BY u.id DESC
                LIMIT 30;
                " | column -t -s '|'
                ;;
            2)
                read -p "Введи ID или username: " query
                exec_sql "
                SELECT 
                    u.id,
                    u.username,
                    u.first_name,
                    u.last_name,
                    COALESCE(up.points, 0) as points,
                    u.posts_count,
                    u.referrer_id,
                    u.created_at,
                    u.is_banned,
                    u.ban_reason
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                WHERE u.id = '$query' OR u.username LIKE '%$query%';
                " | while IFS="|" read -r id username fn ln points posts ref created banned reason; do
                    echo -e "\n${WHITE}📋 ИНФО:${NC}"
                    echo "ID: $id"
                    echo "Username: @$username"
                    echo "Имя: $fn $ln"
                    echo "Монеты: $points"
                    echo "Постов: $posts"
                    echo "Реферер: $ref"
                    echo "Регистрация: $created"
                    echo "Бан: $([ "$banned" = "1" ] && echo "ДА ($reason)" || echo "НЕТ")"
                done
                ;;
            3)
                read -p "ID пользователя: " user_id
                read -p "Причина бана: " reason
                exec_sql "
                UPDATE users 
                SET is_banned=1, ban_reason='$reason', banned_at=CURRENT_TIMESTAMP 
                WHERE id=$user_id;
                "
                echo -e "${GREEN}✅ Забанен!${NC}"
                ;;
            4)
                read -p "ID пользователя: " user_id
                exec_sql "UPDATE users SET is_banned=0, ban_reason=NULL WHERE id=$user_id;"
                echo -e "${GREEN}✅ Разбанен!${NC}"
                ;;
            5)
                echo -e "\n${RED}⛔ ЗАБАНЕННЫЕ:${NC}"
                exec_sql "
                SELECT id, username, ban_reason, banned_at 
                FROM users WHERE is_banned=1 
                ORDER BY banned_at DESC;
                " | column -t -s '|'
                ;;
            6)
                read -p "ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;")
                echo "Текущий баланс: $CURRENT"
                read -p "Новый баланс: " new_points
                exec_sql "
                INSERT INTO user_points (user_id, points) VALUES ($user_id, $new_points)
                ON CONFLICT(user_id) DO UPDATE SET points=$new_points;
                "
                echo -e "${GREEN}✅ Изменено!${NC}"
                ;;
            7)
                echo -e "\n${YELLOW}🏆 ТОП-10 ПО МОНЕТАМ:${NC}"
                exec_sql "
                SELECT u.id, u.username, COALESCE(up.points,0) as p 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY p DESC LIMIT 10;
                " | nl | column -t
                ;;
            8)
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;")
                ACTIVE=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=0;")
                BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;")
                WITH_POSTS=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts;")
                echo -e "\n📊 Статистика:"
                echo "Всего: $TOTAL"
                echo "Активных: $ACTIVE"
                echo "Забанено: $BANNED"
                echo "С постами: $WITH_POSTS"
                ;;
            9)
                read -p "ID пользователя для удаления: " user_id
                read -p "${RED}ТОЧНО?? (yes/no): ${NC}" confirm
                if [ "$confirm" = "yes" ]; then
                    exec_sql "DELETE FROM posts WHERE user_id=$user_id;"
                    exec_sql "DELETE FROM user_points WHERE user_id=$user_id;"
                    exec_sql "DELETE FROM points_log WHERE user_id=$user_id;"
                    exec_sql "DELETE FROM users WHERE id=$user_id;"
                    echo -e "${RED}🗑️ Удален!${NC}"
                fi
                ;;
            10)
                read -p "ID пользователя: " user_id
                read -p "Новый username (без @): " new_username
                exec_sql "UPDATE users SET username='$new_username' WHERE id=$user_id;"
                echo -e "${GREEN}✅ Изменено!${NC}"
                ;;
            11)
                read -p "ID пользователя: " user_id
                exec_sql "UPDATE users SET posts_count=0 WHERE id=$user_id;"
                exec_sql "DELETE FROM user_points WHERE user_id=$user_id;"
                echo -e "${GREEN}✅ Сброшено!${NC}"
                ;;
            0) break ;;
        esac
        echo ""
        read -p "Enter для продолжения..."
    done
}

# Функция управления постами
post_management() {
    while true; do
        clear
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${WHITE}📝 УПРАВЛЕНИЕ ПОСТАМИ${NC}"
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        echo -e "${GREEN}1)  Ожидают модерации${NC}"
        echo -e "${GREEN}2)  Все посты${NC}"
        echo -e "${GREEN}3)  Поиск поста${NC}"
        echo -e "${GREEN}4)  ✅ Одобрить пост${NC}"
        echo -e "${GREEN}5)  ❌ Отклонить пост${NC}"
        echo -e "${GREEN}6)  🗑️ Удалить пост${NC}"
        echo -e "${GREEN}7)  📊 Статистика постов${NC}"
        echo -e "${GREEN}8)  🔄 Массовое одобрение${NC}"
        echo -e "${GREEN}9)  📈 Посты по дням${NC}"
        echo -e "${GREEN}0)  Назад${NC}"
        echo ""
        read -p "Выбери: " post_choice
        
        case $post_choice in
            1)
                echo -e "\n${YELLOW}⏳ ОЖИДАЮТ МОДЕРАЦИИ:${NC}"
                exec_sql "
                SELECT id, user_id, substr(content,1,50), created_at 
                FROM posts WHERE status='pending' 
                ORDER BY created_at;
                " | column -t -s '|'
                ;;
            2)
                echo -e "\n${CYAN}📋 ВСЕ ПОСТЫ (последние 30):${NC}"
                exec_sql "
                SELECT id, user_id, status, substr(content,1,30), created_at 
                FROM posts ORDER BY id DESC LIMIT 30;
                " | column -t -s '|'
                ;;
            3)
                read -p "ID поста: " post_id
                exec_sql "SELECT * FROM posts WHERE id=$post_id;" | while IFS="|" read -r id user content media_type media_id status created moderated moderated_by; do
                    echo -e "\n${WHITE}📋 ПОСТ #$id${NC}"
                    echo "Автор: $user"
                    echo "Статус: $status"
                    echo "Тип: $media_type"
                    echo "Создан: $created"
                    echo "Модерирован: $moderated ($moderated_by)"
                    echo -e "\nТекст:\n$content"
                done
                ;;
            4)
                read -p "ID поста: " post_id
                exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';"
                echo -e "${GREEN}✅ Одобрен!${NC}"
                ;;
            5)
                read -p "ID поста: " post_id
                exec_sql "UPDATE posts SET status='rejected', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';"
                echo -e "${RED}❌ Отклонен!${NC}"
                ;;
            6)
                read -p "ID поста: " post_id
                read -p "${RED}Удалить? (yes/no): ${NC}" confirm
                [ "$confirm" = "yes" ] && exec_sql "DELETE FROM posts WHERE id=$post_id;" && echo -e "${RED}🗑️ Удален!${NC}"
                ;;
            7)
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM posts;")
                APPROVED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='approved';")
                REJECTED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='rejected';")
                PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
                echo -e "\n📊 Статистика:"
                echo "Всего: $TOTAL"
                echo "✅ Одобрено: $APPROVED"
                echo "❌ Отклонено: $REJECTED"
                echo "⏳ В ожидании: $PENDING"
                ;;
            8)
                read -p "ID пользователя (оставь пусто для всех): " user_id
                if [ -z "$user_id" ]; then
                    exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE status='pending';"
                else
                    exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE user_id=$user_id AND status='pending';"
                fi
                echo -e "${GREEN}✅ Массовое одобрение выполнено!${NC}"
                ;;
            9)
                echo -e "\n${CYAN}📅 ПОСТЫ ПО ДНЯМ:${NC}"
                exec_sql "
                SELECT DATE(created_at), COUNT(*) 
                FROM posts 
                GROUP BY DATE(created_at) 
                ORDER BY DATE(created_at) DESC 
                LIMIT 14;
                " | column -t -s '|'
                ;;
            0) break ;;
        esac
        echo ""
        read -p "Enter для продолжения..."
    done
}

# Функция управления монетами
points_management() {
    while true; do
        clear
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${WHITE}💰 УПРАВЛЕНИЕ МОНЕТАМИ${NC}"
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        echo -e "${GREEN}1)  Начислить всем${NC}"
        echo -e "${GREEN}2)  Начислить пользователю${NC}"
        echo -e "${GREEN}3)  Списать у пользователя${NC}"
        echo -e "${GREEN}4)  Обнулить баланс${NC}"
        echo -e "${GREEN}5)  История начислений${NC}"
        echo -e "${GREEN}6)  Топ по тратам${NC}"
        echo -e "${GREEN}7)  Общий пул монет${NC}"
        echo -e "${GREEN}0)  Назад${NC}"
        echo ""
        read -p "Выбери: " points_choice
        
        case $points_choice in
            1)
                read -p "Сумма для всех: " amount
                read -p "Причина: " reason
                exec_sql "
                INSERT INTO user_points (user_id, points) 
                SELECT id, $amount FROM users WHERE is_banned=0
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                "
                echo -e "${GREEN}✅ Начислено всем!${NC}"
                ;;
            2)
                read -p "ID пользователя: " user_id
                read -p "Сумма: " amount
                read -p "Причина: " reason
                exec_sql "
                INSERT INTO user_points (user_id, points) VALUES ($user_id, $amount)
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, $amount, '$reason');
                "
                echo -e "${GREEN}✅ Начислено!${NC}"
                ;;
            3)
                read -p "ID пользователя: " user_id
                read -p "Сумма списания: " amount
                read -p "Причина: " reason
                exec_sql "
                UPDATE user_points SET points = points - $amount WHERE user_id=$user_id;
                INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, -$amount, '$reason');
                "
                echo -e "${GREEN}✅ Списано!${NC}"
                ;;
            4)
                read -p "ID пользователя: " user_id
                exec_sql "UPDATE user_points SET points=0 WHERE user_id=$user_id;"
                echo -e "${YELLOW}🔄 Баланс обнулен!${NC}"
                ;;
            5)
                echo -e "\n${CYAN}📜 ИСТОРИЯ НАЧИСЛЕНИЙ:${NC}"
                exec_sql "
                SELECT created_at, user_id, points, reason 
                FROM points_log 
                ORDER BY created_at DESC 
                LIMIT 30;
                " | column -t -s '|'
                ;;
            6)
                echo -e "\n${PURPLE}💸 ТОП ПО ТРАТАМ (если был бы магазин):${NC}"
                echo "Пока не реализовано"
                ;;
            7)
                TOTAL_POOL=$(exec_sql "SELECT SUM(points) FROM user_points;")
                AVG_BALANCE=$(exec_sql "SELECT AVG(points) FROM user_points;")
                MAX_BALANCE=$(exec_sql "SELECT MAX(points) FROM user_points;")
                echo -e "\n💰 Общий пул монет: $TOTAL_POOL"
                echo "Средний баланс: $AVG_BALANCE"
                echo "Макс. баланс: $MAX_BALANCE"
                ;;
            0) break ;;
        esac
        echo ""
        read -p "Enter для продолжения..."
    done
}

# Функция системных операций
system_operations() {
    while true; do
        clear
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${WHITE}⚙️ СИСТЕМНЫЕ ОПЕРАЦИИ${NC}"
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        echo -e "${GREEN}1)  🚀 Запустить бота${NC}"
        echo -e "${GREEN}2)  🛑 Остановить бота${NC}"
        echo -e "${GREEN}3)  🔄 Перезапустить${NC}"
        echo -e "${GREEN}4)  🏗️ Пересобрать${NC}"
        echo -e "${GREEN}5)  📦 Создать бэкап${NC}"
        echo -e "${GREEN}6)  🔄 Восстановить из бэкапа${NC}"
        echo -e "${GREEN}7)  🗃️ Миграция БД${NC}"
        echo -e "${GREEN}8)  🔍 Проверить обновления${NC}"
        echo -e "${GREEN}9)  🧹 Очистить логи${NC}"
        echo -e "${GREEN}10) 📊 Ресурсы сервера${NC}"
        echo -e "${GREEN}11) 🔌 Переподключить к API${NC}"
        echo -e "${GREEN}0)  Назад${NC}"
        echo ""
        read -p "Выбери: " sys_choice
        
        case $sys_choice in
            1)
                cd docker && docker-compose up -d && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот запущен!${NC}"
                ;;
            2)
                cd docker && docker-compose stop && cd "$PROJECT_ROOT"
                echo -e "${YELLOW}🛑 Бот остановлен!${NC}"
                ;;
            3)
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🔄 Бот перезапущен!${NC}"
                ;;
            4)
                cd docker && docker-compose down && docker-compose up -d --build && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🏗️ Бот пересобран!${NC}"
                ;;
            5)
                ./scripts/backup.sh
                ;;
            6)
                ./scripts/restore.sh
                ;;
            7)
                docker exec ekb-anon-bot python /app/src/migrate_db.py
                ;;
            8)
                git fetch origin
                LOCAL=$(git rev-parse HEAD)
                REMOTE=$(git rev-parse origin/main)
                if [ "$LOCAL" = "$REMOTE" ]; then
                    echo -e "${GREEN}✅ Версия актуальна!${NC}"
                else
                    echo -e "${YELLOW}📥 Есть обновление! Запусти update_from_github.sh${NC}"
                fi
                ;;
            9)
                > logs/bot.log
                echo -e "${GREEN}🧹 Логи очищены!${NC}"
                ;;
            10)
                echo -e "\n${CYAN}💻 РЕСУРСЫ СЕРВЕРА:${NC}"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
                echo "DISK: $(df -h . | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
                ;;
            11)
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🔌 Бот переподключен!${NC}"
                ;;
            0) break ;;
        esac
        echo ""
        read -p "Enter для продолжения..."
    done
}

# Функция статистики и аналитики
stats_analytics() {
    while true; do
        clear
        echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${WHITE}📊 СТАТИСТИКА И АНАЛИТИКА${NC}"
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        
        # Сбор статистики
        TODAY=$(date +%Y-%m-%d)
        USERS_TODAY=$(exec_sql "SELECT COUNT(*) FROM users WHERE DATE(created_at)='$TODAY';")
        POSTS_TODAY=$(exec_sql "SELECT COUNT(*) FROM posts WHERE DATE(created_at)='$TODAY';")
        POINTS_TODAY=$(exec_sql "SELECT COALESCE(SUM(points),0) FROM points_log WHERE DATE(created_at)='$TODAY';")
        
        echo -e "${GREEN}СЕГОДНЯ:${NC}"
        echo "   Новых пользователей: $USERS_TODAY"
        echo "   Новых постов: $POSTS_TODAY"
        echo "   Начислено монет: $POINTS_TODAY"
        echo ""
        
        echo -e "${CYAN}────────────────────────────────────────${NC}"
        echo -e "${GREEN}1)  Детальная статистика по дням${NC}"
        echo -e "${GREEN}2)  Активность по часам${NC}"
        echo -e "${GREEN}3)  Типы контента${NC}"
        echo -e "${GREEN}4)  Эффективность модерации${NC}"
        echo -e "${GREEN}5)  Реферальная статистика${NC}"
        echo -e "${GREEN}6)  Удержание пользователей${NC}"
        echo -e "${GREEN}7)  Экспорт в CSV${NC}"
        echo -e "${GREEN}0)  Назад${NC}"
        echo ""
        read -p "Выбери: " stats_choice
        
        case $stats_choice in
            1)
                echo -e "\n${CYAN}📅 ПОСЛЕДНИЕ 14 ДНЕЙ:${NC}"
                exec_sql "
                SELECT 
                    DATE(created_at) as date,
                    COUNT(DISTINCT user_id) as users,
                    COUNT(*) as posts,
                    SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) as approved
                FROM posts 
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 14;
                " | column -t -s '|'
                ;;
            2)
                echo -e "\n${CYAN}⏰ АКТИВНОСТЬ ПО ЧАСАМ:${NC}"
                exec_sql "
                SELECT 
                    strftime('%H', created_at) as hour,
                    COUNT(*) as posts
                FROM posts 
                GROUP BY hour
                ORDER BY hour;
                " | column -t -s '|'
                ;;
            3)
                echo -e "\n${CYAN}🎨 ТИПЫ КОНТЕНТА:${NC}"
                exec_sql "
                SELECT 
                    COALESCE(media_type, 'text') as type,
                    COUNT(*) as count
                FROM posts 
                GROUP BY media_type;
                " | column -t -s '|'
                ;;
            4)
                AVG_TIME=$(exec_sql "SELECT AVG(strftime('%s', moderated_at) - strftime('%s', created_at)) / 3600.0 FROM posts WHERE moderated_at IS NOT NULL;")
                echo -e "\n⏱️ Среднее время модерации: $AVG_TIME часов"
                ;;
            5)
                echo -e "\n${CYAN}👥 РЕФЕРАЛЬНАЯ СТАТИСТИКА:${NC}"
                exec_sql "
                SELECT 
                    COUNT(*) as total_refs,
                    COUNT(DISTINCT referrer_id) as referrers,
                    AVG(referrals) as avg_per_user
                FROM (
                    SELECT referrer_id, COUNT(*) as referrals 
                    FROM users 
                    WHERE referrer_id IS NOT NULL 
                    GROUP BY referrer_id
                );
                " | column -t -s '|'
                ;;
            6)
                echo -e "\n${CYAN}🔄 УДЕРЖАНИЕ:${NC}"
                exec_sql "
                SELECT 
                    COUNT(DISTINCT user_id) as active_users
                FROM posts 
                WHERE created_at > datetime('now', '-7 days');
                " | while read active; do
                    TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;")
                    PERCENT=$((active * 100 / TOTAL))
                    echo "Активных за 7 дней: $active ($PERCENT%)"
                done
                ;;
            7)
                echo -e "${YELLOW}Экспорт в CSV...${NC}"
                exec_sql ".mode csv
.headers on
SELECT * FROM users;
" > /tmp/users_export.csv
                echo -e "${GREEN}✅ Экспортировано в /tmp/users_export.csv${NC}"
                ;;
            0) break ;;
        esac
        echo ""
        read -p "Enter для продолжения..."
    done
}

# ГЛАВНОЕ МЕНЮ
while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}            ${WHITE} MEGA ADMIN CONSOLE v1.0 ${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                ${CYAN}EKB Anon Bot${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    
    check_status
    
    echo -e "\n${PURPLE}════════════════════════════════════════════${NC}"
    echo -e "${WHITE}ГЛАВНОЕ МЕНЮ${NC}"
    echo -e "${PURPLE}────────────────────────────────────────${NC}"
    echo -e "${GREEN}1)  👥 Управление пользователями${NC}"
    echo -e "${GREEN}2)  📝 Управление постами${NC}"
    echo -e "${GREEN}3)  💰 Управление монетами${NC}"
    echo -e "${GREEN}4)  ⚙️ Системные операции${NC}"
    echo -e "${GREEN}5)  📊 Статистика и аналитика${NC}"
    echo -e "${GREEN}6)  📋 Логи${NC}"
    echo -e "${GREEN}7)  🔄 Быстрые действия${NC}"
    echo -e "${GREEN}8)  🛠️ Диагностика${NC}"
    echo -e "${GREEN}0)  🚪 Выход${NC}"
    echo ""
    read -p "Выбери раздел: " main_choice
    
    case $main_choice in
        1) user_management ;;
        2) post_management ;;
        3) points_management ;;
        4) system_operations ;;
        5) stats_analytics ;;
        6) show_logs ;;
        7)
            echo -e "\n${YELLOW}БЫСТРЫЕ ДЕЙСТВИЯ:${NC}"
            echo "1) Перезапустить бота"
            echo "2) Сделать бэкап"
            echo "3) Посмотреть ошибки"
            echo "4) Одобрить все посты"
            read -p "Выбери: " quick
            case $quick in
                1) cd docker && docker-compose restart ;;
                2) ./scripts/backup.sh ;;
                3) cd docker && docker-compose logs --tail=100 --no-log-prefix 2>&1 | grep -i error ;;
                4) exec_sql "UPDATE posts SET status='approved' WHERE status='pending';" ;;
            esac
            ;;
        8)
            echo -e "\n${CYAN}🛠️ ДИАГНОСТИКА:${NC}"
            echo "Пинг бота: $(docker exec ekb-anon-bot python -c "import requests; print('OK' if requests.get('https://api.telegram.org').status_code==200 else 'FAIL')" 2>/dev/null)"
            echo "Подключение к БД: $(docker exec ekb-anon-bot python -c "import sqlite3; conn=sqlite3.connect('data/anon_ekb.db'); print('OK'); conn.close()" 2>/dev/null)"
            echo "Права на папки: $(ls -ld data/ logs/ | awk '{print $1, $3}')"
            ;;
        0)
            echo -e "\n${GREEN}👋 Пока! Заходи еще!${NC}"
            exit 0
            ;;
    esac
    
    echo ""
    read -p "Нажми Enter для продолжения..."
done