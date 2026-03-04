#!/bin/bash

# ============================================
# EKB ANON ADMIN - АДМИНСКАЯ КОНСОЛЬ
# Версия: 2.0 / ЕКБ-СТИЛЬ
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

# Функция заголовка
print_header() {
    local title="$1"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃${NC}  ${WHITE}$title${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# Функция проверки статуса
check_status() {
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                     СТАТУС БОТА${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    
    if docker ps | grep -q ekb-anon-bot; then
        echo -e "   ${GREEN}✅ БОТ РАБОТАЕТ${NC}"
        
        CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" ekb-anon-bot 2>/dev/null | sed 's/%//')
        MEM=$(docker stats --no-stream --format "{{.MemUsage}}" ekb-anon-bot 2>/dev/null)
        MEM_PERCENT=$(docker stats --no-stream --format "{{.MemPerc}}" ekb-anon-bot 2>/dev/null)
        
        echo -e "   💻 Процессор: ${CPU}%"
        echo -e "   🐏 Память: ${MEM} (${MEM_PERCENT})"
        
        UPTIME=$(docker inspect --format='{{.State.StartedAt}}' ekb-anon-bot | xargs date -d 2>/dev/null)
        echo -e "   ⏰ Запущен: $UPTIME"
    else
        echo -e "   ${RED}❌ БОТ ОСТАНОВЛЕН${NC}"
        echo -e "   ${YELLOW}💡 Используйте '4' → '1' для запуска${NC}"
    fi
    
    # Статистика
    TOTAL_USERS=$(exec_sql "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
    TOTAL_POSTS=$(exec_sql "SELECT COUNT(*) FROM posts;" 2>/dev/null || echo "0")
    PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';" 2>/dev/null || echo "0")
    BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;" 2>/dev/null || echo "0")
    
    echo -e "\n   👥 Пользователей: ${WHITE}$TOTAL_USERS${NC}"
    
    if [ "$PENDING" -gt 0 ]; then
        echo -e "   📝 Постов: $TOTAL_POSTS ${YELLOW}(+$PENDING ожидают)${NC}"
    else
        echo -e "   📝 Постов: $TOTAL_POSTS"
    fi
    
    if [ "$BANNED" -gt 0 ]; then
        echo -e "   🔴 Заблокировано: ${RED}$BANNED${NC}"
    else
        echo -e "   🔴 Заблокировано: $BANNED"
    fi
}

# Функция прогресс-бара
show_progress() {
    local message="$1"
    echo -n "${YELLOW}⏳ $message ${NC}"
    for i in {1..20}; do
        echo -n "▓"
        sleep 0.05
    done
    echo -e " ${GREEN}✅ ГОТОВО${NC}"
}

# ============================================
# УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ
# ============================================
user_management() {
    while true; do
        clear
        print_header "👥 УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ"
        
        TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
        ACTIVE=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=0;" 2>/dev/null || echo "0")
        BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;" 2>/dev/null || echo "0")
        NEW_TODAY=$(exec_sql "SELECT COUNT(*) FROM users WHERE DATE(created_at)=DATE('now');" 2>/dev/null || echo "0")
        
        echo -e "\n${CYAN}📊 Статистика:${NC}"
        echo -e "   👥 Всего: ${WHITE}$TOTAL${NC}"
        echo -e "   ✅ Активных: $ACTIVE"
        echo -e "   🔴 Заблокировано: $BANNED"
        echo -e "   🆕 Новых сегодня: $NEW_TODAY"
        echo -e "${GRAY}────────────────────────────────────────${NC}"
        
        echo -e "${GREEN}1)  📋 Список пользователей${NC}"
        echo -e "${GREEN}2)  🔍 Поиск пользователя${NC}"
        echo -e "${RED}3)  ⛔ Заблокировать${NC}"
        echo -e "${GREEN}4)  ✅ Разблокировать${NC}"
        echo -e "${RED}5)  📋 Список заблокированных${NC}"
        echo -e "${YELLOW}6)  💰 Изменить баланс${NC}"
        echo -e "${YELLOW}7)  🏆 Топ по монетам${NC}"
        echo -e "${RED}8)  🗑️ Удалить пользователя${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите действие: "${NC})" user_choice
        
        case $user_choice in
            1) 
                echo -e "\n${CYAN}👥 Последние 30 пользователей:${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    COALESCE(u.username, '—'),
                    COALESCE(up.points, 0),
                    u.posts_count,
                    CASE WHEN u.is_banned = 1 THEN '🔴' ELSE '✅' END,
                    DATE(u.created_at)
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                ORDER BY u.id DESC
                LIMIT 30;
                " 2>/dev/null | column -t -s '|'
                ;;
            2)
                read -p "🔍 Введите ID или username: " query
                echo -e "\n${CYAN}Результаты поиска:${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    u.username,
                    u.first_name,
                    u.last_name,
                    COALESCE(up.points, 0),
                    u.posts_count,
                    u.referrer_id,
                    u.created_at,
                    CASE WHEN u.is_banned = 1 THEN 'ДА' ELSE 'НЕТ' END,
                    COALESCE(u.ban_reason, '—')
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                WHERE u.id = '$query' OR u.username LIKE '%$query%' OR u.first_name LIKE '%$query%';
                " 2>/dev/null | while IFS="|" read -r id username fn ln points posts ref created banned reason; do
                    echo -e "\n${WHITE}════════════════════════════════════${NC}"
                    echo -e "${WHITE}ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ${NC}"
                    echo -e "${WHITE}════════════════════════════════════${NC}"
                    echo -e "${GREEN}ID:${NC} $id"
                    echo -e "${GREEN}Username:${NC} @$username"
                    echo -e "${GREEN}Имя:${NC} $fn $ln"
                    echo -e "${YELLOW}Монеты:${NC} $points"
                    echo -e "${CYAN}Постов:${NC} $posts"
                    echo -e "${PURPLE}Реферер:${NC} $ref"
                    echo -e "${BLUE}Регистрация:${NC} $created"
                    
                    if [ "$banned" = "ДА" ]; then
                        echo -e "${RED}Статус: ЗАБЛОКИРОВАН${NC}"
                        echo -e "${RED}Причина: $reason${NC}"
                    else
                        echo -e "${GREEN}Статус: Активен${NC}"
                    fi
                done
                ;;
            3)
                echo -e "\n${RED}⛔ БЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ${NC}"
                read -p "ID пользователя: " user_id
                EXISTS=$(exec_sql "SELECT username FROM users WHERE id=$user_id;" 2>/dev/null)
                if [ -z "$EXISTS" ]; then
                    echo -e "${RED}❌ Пользователь не найден!${NC}"
                else
                    read -p "Причина блокировки: " reason
                    exec_sql "
                    UPDATE users 
                    SET is_banned=1, ban_reason='$reason', banned_at=CURRENT_TIMESTAMP 
                    WHERE id=$user_id;
                    " 2>/dev/null
                    echo -e "${GREEN}✅ Пользователь $user_id заблокирован${NC}"
                fi
                ;;
            4)
                echo -e "\n${GREEN}✅ РАЗБЛОКИРОВКА${NC}"
                read -p "ID пользователя: " user_id
                exec_sql "UPDATE users SET is_banned=0, ban_reason=NULL WHERE id=$user_id;" 2>/dev/null
                echo -e "${GREEN}✅ Пользователь $user_id разблокирован${NC}"
                ;;
            5)
                echo -e "\n${RED}⛔ СПИСОК ЗАБЛОКИРОВАННЫХ:${NC}"
                exec_sql "
                SELECT id, username, ban_reason, datetime(banned_at, 'localtime') 
                FROM users WHERE is_banned=1 
                ORDER BY banned_at DESC;
                " 2>/dev/null | column -t -s '|'
                [ $? -ne 0 ] && echo "Нет заблокированных пользователей"
                ;;
            6)
                echo -e "\n${YELLOW}💰 ИЗМЕНЕНИЕ БАЛАНСА${NC}"
                read -p "ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;" 2>/dev/null)
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                echo -e "${GREEN}1) Начислить${NC}"
                echo -e "${RED}2) Списать${NC}"
                read -p "Выберите: " op
                read -p "Сумма: " amount
                if [ "$op" = "1" ]; then
                    exec_sql "
                    INSERT INTO user_points (user_id, points) VALUES ($user_id, $amount)
                    ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                    INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, $amount, 'admin_add');
                    " 2>/dev/null
                    echo -e "${GREEN}✅ Начислено $amount${NC}"
                else
                    exec_sql "
                    UPDATE user_points SET points = points - $amount WHERE user_id=$user_id;
                    INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, -$amount, 'admin_sub');
                    " 2>/dev/null
                    echo -e "${RED}✅ Списано $amount${NC}"
                fi
                ;;
            7)
                echo -e "\n${YELLOW}🏆 ТОП ПО МОНЕТАМ:${NC}"
                exec_sql "
                SELECT 
                    u.id, 
                    COALESCE(u.username, '—'), 
                    COALESCE(up.points, 0) 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 10;
                " 2>/dev/null | nl -w3 -s') ' | while read line; do
                    echo -e "${YELLOW}$line${NC}"
                done
                ;;
            8)
                echo -e "\n${RED}⚠️ УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC}"
                read -p "ID пользователя: " user_id
                USER_INFO=$(exec_sql "SELECT username FROM users WHERE id=$user_id;" 2>/dev/null)
                if [ -n "$USER_INFO" ]; then
                    echo -e "${RED}Пользователь: @$USER_INFO${NC}"
                    read -p "${RED}ПОДТВЕРДИТЕ УДАЛЕНИЕ (YES): ${NC}" confirm
                    if [ "$confirm" = "YES" ]; then
                        show_progress "Удаление данных"
                        exec_sql "DELETE FROM posts WHERE user_id=$user_id;" 2>/dev/null
                        exec_sql "DELETE FROM user_points WHERE user_id=$user_id;" 2>/dev/null
                        exec_sql "DELETE FROM points_log WHERE user_id=$user_id;" 2>/dev/null
                        exec_sql "DELETE FROM users WHERE id=$user_id;" 2>/dev/null
                        echo -e "${GREEN}✅ Пользователь удален${NC}"
                    fi
                else
                    echo -e "${RED}❌ Пользователь не найден${NC}"
                fi
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# УПРАВЛЕНИЕ ПОСТАМИ
# ============================================
post_management() {
    while true; do
        clear
        print_header "📝 УПРАВЛЕНИЕ ПОСТАМИ"
        
        TOTAL=$(exec_sql "SELECT COUNT(*) FROM posts;" 2>/dev/null || echo "0")
        APPROVED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='approved';" 2>/dev/null || echo "0")
        REJECTED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='rejected';" 2>/dev/null || echo "0")
        PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';" 2>/dev/null || echo "0")
        
        echo -e "\n${CYAN}📊 Статистика:${NC}"
        echo -e "   📝 Всего: $TOTAL | ✅ Одобрено: $APPROVED | ❌ Отклонено: $REJECTED | ⏳ В очереди: ${YELLOW}$PENDING${NC}"
        echo -e "${GRAY}────────────────────────────────────────${NC}"
        
        echo -e "${YELLOW}1)  ⏳ Ожидают модерации${NC}"
        echo -e "${GREEN}2)  📋 Все посты${NC}"
        echo -e "${CYAN}3)  🔍 Поиск поста${NC}"
        echo -e "${GREEN}4)  ✅ Одобрить пост${NC}"
        echo -e "${RED}5)  ❌ Отклонить пост${NC}"
        echo -e "${RED}6)  🗑️ Удалить пост${NC}"
        echo -e "${CYAN}7)  📈 Посты по дням${NC}"
        echo -e "${GREEN}8)  🔄 Одобрить все в очереди${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите действие: "${NC})" post_choice
        
        case $post_choice in
            1)
                echo -e "\n${YELLOW}⏳ ОЖИДАЮТ МОДЕРАЦИИ:${NC}"
                exec_sql "
                SELECT id, user_id, substr(content,1,70), datetime(created_at, 'localtime') 
                FROM posts WHERE status='pending' 
                ORDER BY created_at;
                " 2>/dev/null | while IFS="|" read -r id user content date; do
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "ID: $id | Автор: $user | Дата: $date"
                    echo -e "Текст: $content..."
                done
                ;;
            2)
                echo -e "\n${CYAN}📋 ВСЕ ПОСТЫ (последние 30):${NC}"
                exec_sql "
                SELECT 
                    id, 
                    user_id, 
                    CASE status 
                        WHEN 'approved' THEN '✅' 
                        WHEN 'rejected' THEN '❌' 
                        ELSE '⏳' 
                    END,
                    substr(content,1,40), 
                    datetime(created_at, 'localtime')
                FROM posts ORDER BY id DESC LIMIT 30;
                " 2>/dev/null | column -t -s '|'
                ;;
            3)
                read -p "🔍 Введите ID поста: " post_id
                echo -e "\n${CYAN}🔍 ПОСТ #$post_id${NC}"
                exec_sql "SELECT * FROM posts WHERE id=$post_id;" 2>/dev/null | while IFS="|" read -r id user content media_type media_id status created moderated moderated_by; do
                    echo -e "${WHITE}════════════════════════════════════${NC}"
                    echo -e "${GREEN}ID:${NC} $id"
                    echo -e "${GREEN}Автор:${NC} $user"
                    echo -e "${GREEN}Статус:${NC} $( [ "$status" = "approved" ] && echo "✅ Одобрен" || [ "$status" = "rejected" ] && echo "❌ Отклонен" || echo "⏳ Ожидает" )"
                    echo -e "${GREEN}Тип:${NC} ${media_type:-текст}"
                    echo -e "${GREEN}Создан:${NC} $created"
                    echo -e "${GREEN}Модерирован:${NC} ${moderated:-нет}"
                    echo -e "${WHITE}────────────────────────${NC}"
                    echo -e "${CYAN}Текст:${NC}\n$content"
                done
                ;;
            4)
                read -p "✅ ID поста для одобрения: " post_id
                exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${GREEN}✅ Пост #$post_id одобрен${NC}" || echo -e "${RED}❌ Ошибка или пост уже обработан${NC}"
                ;;
            5)
                read -p "❌ ID поста для отклонения: " post_id
                exec_sql "UPDATE posts SET status='rejected', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${RED}❌ Пост #$post_id отклонен${NC}" || echo -e "${RED}❌ Ошибка или пост уже обработан${NC}"
                ;;
            6)
                read -p "🗑️ ID поста для удаления: " post_id
                read -p "${RED}ПОДТВЕРДИТЕ УДАЛЕНИЕ (yes): ${NC}" confirm
                [ "$confirm" = "yes" ] && exec_sql "DELETE FROM posts WHERE id=$post_id;" 2>/dev/null && echo -e "${RED}🗑️ Пост #$post_id удален${NC}"
                ;;
            7)
                echo -e "\n${CYAN}📈 ПОСТЫ ПО ДНЯМ:${NC}"
                exec_sql "
                SELECT 
                    DATE(created_at),
                    COUNT(*),
                    SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END)
                FROM posts 
                GROUP BY DATE(created_at)
                ORDER BY DATE(created_at) DESC
                LIMIT 14;
                " 2>/dev/null | column -t -s '|'
                ;;
            8)
                PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';" 2>/dev/null)
                if [ "$PENDING" -gt 0 ]; then
                    read -p "Одобрить все $PENDING постов? (yes): " confirm
                    [ "$confirm" = "yes" ] && exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE status='pending';" 2>/dev/null && echo -e "${GREEN}✅ Одобрено $PENDING постов${NC}"
                else
                    echo -e "${YELLOW}⚠️ Нет постов на модерации${NC}"
                fi
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# УПРАВЛЕНИЕ МОНЕТАМИ
# ============================================
points_management() {
    while true; do
        clear
        print_header "💰 УПРАВЛЕНИЕ МОНЕТАМИ"
        
        TOTAL_POOL=$(exec_sql "SELECT SUM(points) FROM user_points;" 2>/dev/null)
        [ -z "$TOTAL_POOL" ] && TOTAL_POOL=0
        AVG=$(exec_sql "SELECT AVG(points) FROM user_points;" 2>/dev/null)
        [ -z "$AVG" ] && AVG=0
        
        echo -e "\n${CYAN}💰 Общая статистика:${NC}"
        echo -e "   💰 Всего монет: ${YELLOW}$TOTAL_POOL${NC}"
        echo -e "   📊 Средний баланс: $AVG"
        echo -e "${GRAY}────────────────────────────────────────${NC}"
        
        echo -e "${GREEN}1)  💰 Начислить всем${NC}"
        echo -e "${GREEN}2)  💰 Начислить пользователю${NC}"
        echo -e "${RED}3)  💸 Списать у пользователя${NC}"
        echo -e "${YELLOW}4)  🔄 Обнулить баланс${NC}"
        echo -e "${CYAN}5)  📜 История операций${NC}"
        echo -e "${YELLOW}6)  🏆 Топ по монетам${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите действие: "${NC})" points_choice
        
        case $points_choice in
            1)
                read -p "💰 Сумма для всех: " amount
                read -p "Причина: " reason
                show_progress "Начисление"
                exec_sql "
                INSERT INTO user_points (user_id, points) 
                SELECT id, $amount FROM users WHERE is_banned=0
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                INSERT INTO points_log (user_id, points, reason) 
                SELECT id, $amount, '$reason' FROM users WHERE is_banned=0;
                " 2>/dev/null
                echo -e "${GREEN}✅ Начислено $amount всем активным пользователям${NC}"
                ;;
            2)
                read -p "👤 ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;" 2>/dev/null)
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                read -p "💰 Сумма: " amount
                read -p "Причина: " reason
                exec_sql "
                INSERT INTO user_points (user_id, points) VALUES ($user_id, $amount)
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, $amount, '$reason');
                " 2>/dev/null
                echo -e "${GREEN}✅ Начислено $amount пользователю $user_id${NC}"
                ;;
            3)
                read -p "👤 ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;" 2>/dev/null)
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                read -p "💰 Сумма списания: " amount
                read -p "Причина: " reason
                if [ "$amount" -gt "$CURRENT" ]; then
                    echo -e "${RED}❌ Недостаточно монет. Баланс: $CURRENT${NC}"
                else
                    exec_sql "
                    UPDATE user_points SET points = points - $amount WHERE user_id=$user_id;
                    INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, -$amount, '$reason');
                    " 2>/dev/null
                    echo -e "${RED}✅ Списано $amount у пользователя $user_id${NC}"
                fi
                ;;
            4)
                read -p "👤 ID пользователя: " user_id
                read -p "${RED}ОБНУЛИТЬ БАЛАНС? (yes): ${NC}" confirm
                [ "$confirm" = "yes" ] && exec_sql "UPDATE user_points SET points=0 WHERE user_id=$user_id;" 2>/dev/null && echo -e "${YELLOW}🔄 Баланс обнулен${NC}"
                ;;
            5)
                echo -e "\n${CYAN}📜 ПОСЛЕДНИЕ ОПЕРАЦИИ:${NC}"
                exec_sql "
                SELECT 
                    datetime(created_at, 'localtime'),
                    user_id,
                    points,
                    reason
                FROM points_log 
                ORDER BY created_at DESC 
                LIMIT 30;
                " 2>/dev/null | while IFS="|" read -r date user points reason; do
                    if [ "$points" -gt 0 ]; then
                        echo -e "${GREEN}[$date] +$points пользователю $user ($reason)${NC}"
                    else
                        echo -e "${RED}[$date] $points пользователя $user ($reason)${NC}"
                    fi
                done
                ;;
            6)
                echo -e "\n${YELLOW}🏆 ТОП ПО МОНЕТАМ:${NC}"
                exec_sql "
                SELECT 
                    u.id, 
                    COALESCE(u.username, '—'), 
                    COALESCE(up.points, 0) 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 15;
                " 2>/dev/null | nl -w3 -s') ' | while read line; do
                    echo -e "${YELLOW}$line${NC}"
                done
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# СИСТЕМНЫЕ ОПЕРАЦИИ
# ============================================
system_operations() {
    while true; do
        clear
        print_header "⚙️ СИСТЕМНЫЕ ОПЕРАЦИИ"
        
        echo -e "\n${GREEN}1)  🚀 Запустить бота${NC}"
        echo -e "${RED}2)  🛑 Остановить бота${NC}"
        echo -e "${YELLOW}3)  🔄 Перезапустить${NC}"
        echo -e "${BLUE}4)  🏗️ Пересобрать${NC}"
        echo -e "${GREEN}5)  📦 Создать бэкап${NC}"
        echo -e "${CYAN}6)  🔄 Восстановить из бэкапа${NC}"
        echo -e "${PURPLE}7)  🗃️ Миграция БД${NC}"
        echo -e "${YELLOW}8)  🔍 Проверить обновления${NC}"
        echo -e "${RED}9)  🧹 Очистить логи${NC}"
        echo -e "${BLUE}10) 📊 Ресурсы сервера${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите действие: "${NC})" sys_choice
        
        case $sys_choice in
            1)
                show_progress "Запуск"
                cd docker && docker-compose up -d && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот запущен${NC}"
                ;;
            2)
                show_progress "Остановка"
                cd docker && docker-compose stop && cd "$PROJECT_ROOT"
                echo -e "${YELLOW}🛑 Бот остановлен${NC}"
                ;;
            3)
                show_progress "Перезапуск"
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🔄 Бот перезапущен${NC}"
                ;;
            4)
                show_progress "Пересборка"
                cd docker && docker-compose down && docker-compose up -d --build && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🏗️ Бот пересобран${NC}"
                ;;
            5)
                ./scripts/backup.sh
                ;;
            6)
                ./scripts/restore.sh
                ;;
            7)
                echo -e "${YELLOW}🔄 Запуск миграции...${NC}"
                docker exec ekb-anon-bot python /app/src/migrate_db.py
                echo -e "${GREEN}✅ Миграция выполнена${NC}"
                ;;
            8)
                git fetch origin
                LOCAL=$(git rev-parse HEAD)
                REMOTE=$(git rev-parse origin/main 2>/dev/null)
                if [ "$LOCAL" = "$REMOTE" ]; then
                    echo -e "${GREEN}✅ Версия актуальна${NC}"
                else
                    echo -e "${YELLOW}📥 Доступно обновление. Запустите update_from_github.sh${NC}"
                fi
                ;;
            9)
                > logs/bot.log
                echo -e "${GREEN}🧹 Логи очищены${NC}"
                ;;
            10)
                echo -e "\n${CYAN}💻 РЕСУРСЫ СЕРВЕРА:${NC}"
                echo -e "${GRAY}────────────────────────${NC}"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
                echo "Диск: $(df -h . | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
                echo "Аптайм: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# СТАТИСТИКА
# ============================================
stats_analytics() {
    while true; do
        clear
        print_header "📊 СТАТИСТИКА"
        
        TODAY=$(date +%Y-%m-%d)
        USERS_TODAY=$(exec_sql "SELECT COUNT(*) FROM users WHERE DATE(created_at)='$TODAY';" 2>/dev/null || echo "0")
        POSTS_TODAY=$(exec_sql "SELECT COUNT(*) FROM posts WHERE DATE(created_at)='$TODAY';" 2>/dev/null || echo "0")
        POINTS_TODAY=$(exec_sql "SELECT COALESCE(SUM(points),0) FROM points_log WHERE DATE(created_at)='$TODAY';" 2>/dev/null || echo "0")
        
        echo -e "\n${GREEN}СТАТИСТИКА ЗА СЕГОДНЯ:${NC}"
        echo -e "   👥 Новых пользователей: $USERS_TODAY"
        echo -e "   📝 Новых постов: $POSTS_TODAY"
        echo -e "   💰 Начислено монет: $POINTS_TODAY"
        echo -e "${GRAY}────────────────────────────────────────${NC}"
        
        echo -e "${CYAN}1)  📅 По дням${NC}"
        echo -e "${GREEN}2)  ⏰ По часам${NC}"
        echo -e "${YELLOW}3)  🎨 Типы контента${NC}"
        echo -e "${BLUE}4)  ⏱️ Скорость модерации${NC}"
        echo -e "${PURPLE}5)  👥 Рефералы${NC}"
        echo -e "${ORANGE}6)  🔄 Активность пользователей${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите: "${NC})" stats_choice
        
        case $stats_choice in
            1)
                echo -e "\n${CYAN}📅 ПОСЛЕДНИЕ 14 ДНЕЙ:${NC}"
                exec_sql "
                SELECT 
                    DATE(created_at),
                    COUNT(*),
                    COUNT(DISTINCT user_id)
                FROM posts 
                GROUP BY DATE(created_at)
                ORDER BY DATE(created_at) DESC
                LIMIT 14;
                " 2>/dev/null | column -t -s '|'
                ;;
            2)
                echo -e "\n${GREEN}⏰ АКТИВНОСТЬ ПО ЧАСАМ:${NC}"
                exec_sql "
                SELECT 
                    strftime('%H', created_at),
                    COUNT(*)
                FROM posts 
                GROUP BY strftime('%H', created_at)
                ORDER BY strftime('%H', created_at);
                " 2>/dev/null | column -t -s '|'
                ;;
            3)
                echo -e "\n${YELLOW}🎨 ТИПЫ КОНТЕНТА:${NC}"
                exec_sql "
                SELECT 
                    COALESCE(media_type, 'текст'),
                    COUNT(*),
                    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM posts), 1) || '%'
                FROM posts 
                GROUP BY media_type;
                " 2>/dev/null | column -t -s '|'
                ;;
            4)
                AVG_TIME=$(exec_sql "SELECT AVG(strftime('%s', moderated_at) - strftime('%s', created_at)) / 3600.0 FROM posts WHERE moderated_at IS NOT NULL;" 2>/dev/null)
                echo -e "\n⏱️ Среднее время модерации: ${AVG_TIME:-0} часов"
                ;;
            5)
                echo -e "\n${PURPLE}👥 РЕФЕРАЛЬНАЯ СТАТИСТИКА:${NC}"
                TOTAL_REFS=$(exec_sql "SELECT COUNT(*) FROM users WHERE referrer_id IS NOT NULL;" 2>/dev/null)
                UNIQUE_REFS=$(exec_sql "SELECT COUNT(DISTINCT referrer_id) FROM users WHERE referrer_id IS NOT NULL;" 2>/dev/null)
                echo -e "   👥 Всего рефералов: $TOTAL_REFS"
                echo -e "   👤 Уникальных рефереров: $UNIQUE_REFS"
                ;;
            6)
                DAY7=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at > datetime('now', '-7 days');" 2>/dev/null)
                DAY30=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at > datetime('now', '-30 days');" 2>/dev/null)
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;" 2>/dev/null)
                echo -e "\n🔄 АКТИВНОСТЬ ПОЛЬЗОВАТЕЛЕЙ:"
                echo -e "   За 7 дней: $DAY7"
                echo -e "   За 30 дней: $DAY30"
                echo -e "   Всего: $TOTAL"
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# ПРОСМОТР ЛОГОВ
# ============================================
show_logs() {
    while true; do
        clear
        print_header "📋 ПРОСМОТР ЛОГОВ"
        
        echo -e "\n${GREEN}1) 📋 Последние 50 строк${NC}"
        echo -e "${GREEN}2) 📅 Логи за сегодня${NC}"
        echo -e "${RED}3) 🔥 Только ошибки${NC}"
        echo -e "${CYAN}4) 🔄 Логи в реальном времени${NC}"
        echo -e "${GREEN}5) 💾 Сохранить в файл${NC}"
        echo -e "${RED}6) 🧹 Очистить логи${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}9) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите: "${NC})" log_choice
        
        case $log_choice in
            1) cd docker && docker-compose logs --tail=50 --no-log-prefix ;;
            2) cd docker && docker-compose logs --since="$(date +%Y-%m-%d)" --no-log-prefix ;;
            3) cd docker && docker-compose logs --tail=500 --no-log-prefix 2>&1 | grep -i error ;;
            4) cd docker && docker-compose logs -f ;;
            5)
                LOGFILE="/tmp/ekb_logs_$(date +%Y%m%d_%H%M%S).txt"
                cd docker && docker-compose logs --tail=5000 --no-log-prefix > "$LOGFILE"
                echo -e "${GREEN}✅ Логи сохранены: $LOGFILE${NC}"
                ;;
            6)
                > logs/bot.log
                echo -e "${GREEN}🧹 Логи очищены${NC}"
                ;;
            9) exit 0 ;;
            0) break ;;
        esac
        cd "$PROJECT_ROOT" || exit
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# БЫСТРЫЕ ДЕЙСТВИЯ
# ============================================
quick_actions() {
    while true; do
        clear
        print_header "⚡ БЫСТРЫЕ ДЕЙСТВИЯ"
        
        PENDING_COUNT=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';" 2>/dev/null || echo "0")
        
        echo -e "\n${GREEN}1) 🔄 Перезапустить бота${NC}"
        echo -e "${GREEN}2) 📦 Создать бэкап${NC}"
        echo -e "${RED}3) 🔥 Посмотреть ошибки${NC}"
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}4) ✅ Одобрить все посты ($PENDING_COUNT шт)${NC}"
        else
            echo -e "${GRAY}4) ✅ Одобрить все посты (нет в очереди)${NC}"
        fi
        
        echo -e "${CYAN}5) 📊 Показать метрики${NC}"
        echo -e "${PURPLE}6) 🔌 Проверить подключения${NC}"
        echo -e "${YELLOW}7) 🏆 Топ-5 по монетам${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}9) Выход${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}"👉 Выберите: "${NC})" quick_choice
        
        case $quick_choice in
            1)
                show_progress "Перезапуск"
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот перезапущен${NC}"
                ;;
            2)
                ./scripts/backup.sh
                ;;
            3)
                echo -e "\n${RED}Последние ошибки:${NC}"
                cd docker && docker-compose logs --tail=200 --no-log-prefix 2>&1 | grep -i error | tail -20
                ;;
            4)
                if [ "$PENDING_COUNT" -gt 0 ]; then
                    exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE status='pending';" 2>/dev/null
                    echo -e "${GREEN}✅ Одобрено $PENDING_COUNT постов${NC}"
                else
                    echo -e "${YELLOW}⚠️ Нет постов на модерации${NC}"
                fi
                ;;
            5)
                echo -e "\n${CYAN}📊 МЕТРИКИ:${NC}"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
                echo "Диск: $(df -h . | awk 'NR==2 {print $3 "/" $2}')"
                echo "Контейнеров: $(docker ps -q | wc -l)"
                ;;
            6)
                echo -e "\n${PURPLE}🔌 ПРОВЕРКА ПОДКЛЮЧЕНИЙ:${NC}"
                echo -n "Telegram API: "
                docker exec ekb-anon-bot python -c "import requests; print('✅ OK' if requests.get('https://api.telegram.org').status_code==200 else '❌')" 2>/dev/null || echo "❌"
                echo -n "База данных: "
                docker exec ekb-anon-bot python -c "import sqlite3; sqlite3.connect('data/anon_ekb.db'); print('✅ OK')" 2>/dev/null || echo "❌"
                ;;
            7)
                echo -e "\n${YELLOW}🏆 ТОП-5 ПО МОНЕТАМ:${NC}"
                exec_sql "
                SELECT 
                    u.id, 
                    COALESCE(u.username, '—'), 
                    COALESCE(up.points, 0) 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 5;
                " 2>/dev/null | column -t -s '|'
                ;;
            9) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "$(echo -e ${GRAY}"Нажмите Enter для продолжения...${NC}")"
    done
}

# ============================================
# ГЛАВНОЕ МЕНЮ
# ============================================
while true; do
    clear
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃${NC}              EKB ANON ADMIN - КОНСОЛЬ УПРАВЛЕНИЯ              ${BLUE}┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    
    check_status
    
    echo -e "\n${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}1)  👥 Управление пользователями${NC}"
    echo -e "${GREEN}2)  📝 Управление постами${NC}"
    echo -e "${YELLOW}3)  💰 Управление монетами${NC}"
    echo -e "${CYAN}4)  ⚙️  Системные операции${NC}"
    echo -e "${PURPLE}5)  📊 Статистика${NC}"
    echo -e "${BLUE}6)  📋 Просмотр логов${NC}"
    echo -e "${WHITE}7)  ⚡ Быстрые действия${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}9)  🚪 Выход${NC}"
    echo ""
    read -p "$(echo -e ${BLUE}"👉 Выберите раздел [1-9]: "${NC})" main_choice
    
    case $main_choice in
        1) user_management ;;
        2) post_management ;;
        3) points_management ;;
        4) system_operations ;;
        5) stats_analytics ;;
        6) show_logs ;;
        7) quick_actions ;;
        9)
            echo -e "\n${GREEN}👋 До свидания!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Неверный выбор${NC}"
            sleep 1
            ;;
    esac
done
