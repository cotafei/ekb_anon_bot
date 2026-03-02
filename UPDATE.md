# 🔄 Инструкция по обновлению EKB Anonymous Bot

## Быстрое обновление (рекомендуется)

### Linux/macOS
```bash
cd /путь/к/проекту
chmod +x scripts/update_from_github.sh
./scripts/update_from_github.sh
```

### Windows
```batch
cd /путь/к/проекту
scripts\update_from_github.bat
```

## Что делает скрипт обновления?

✅ **Автоматически:**
1. Создает резервную копию (data/, logs/, .env)
2. Скачивает последнюю версию с GitHub
3. Сохраняет твой скрипт миграции
4. Обновляет файлы проекта
5. Запускает миграцию БД
6. Перезапускает бота

✅ **Сохраняет:**
- Базу данных (все посты, пользователи, монеты)
- Логи
- Файл .env с токенами
- Твои личные настройки

## Ручное обновление (если скрипт не подходит)

### 1. Сделай бэкап
```bash
cp -r data backups/data_$(date +%Y%m%d)
cp .env .env.backup
```

### 2. Скачай новую версию
```bash
git pull origin main
# или
git clone https://github.com/cotafei/ekb_anon_bot.git ekb_anon_bot_new
```

### 3. Обнови структуру БД
```bash
cd src
python migrate_db.py
```

### 4. Перезапусти бота
```bash
cd ../docker && docker-compose down && docker-compose up -d --build
```

## История версий

| Версия | Дата | Ключевые изменения |
|--------|------|-------------------|
| 1.1.1 | 03.03.2026 | Исправление багов, скрипт обновления, миграция БД |
| 1.1.0 | 02.03.2026 | Docker, FSM, монеты, рефералы, бэкапы |
| 1.0.0 | 27.02.2026 | Первый релиз |

## Проверка версии

После обновления проверь, что всё работает:

```bash
# Проверь версию в main.py
grep "Версия:" src/main.py

# Посмотри логи
cd docker && docker-compose logs -f
```

## Если что-то пошло не так

### Восстановление из бэкапа
```bash
# Linux/macOS
./scripts/restore.sh

# Windows
scripts\restore.bat
```

### Откат к предыдущей версии
```bash
# 1. Останови бота
cd docker && docker-compose down

# 2. Восстанови файлы из бэкапа
tar -xzf backups/pre_update_backup_*.tar.gz

# 3. Запусти бота
cd docker && docker-compose up -d
```

## Нужна помощь?

Если возникли проблемы:
- Проверь `.env` файл
- Посмотри логи: `cd docker && docker-compose logs -f`
- Создай Issue на GitHub
- Напиши автору: @C0taf31

---

**Совет:** Перед обновлением всегда делай бэкап! Скрипт делает это автоматически, но лишняя копия не помешает. 😉