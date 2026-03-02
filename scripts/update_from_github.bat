@echo off
chcp 65001 > nul
title EKB Anon Bot Updater

echo ===========================================
echo    EKB Anon Bot - Обновление с GitHub
echo ===========================================
echo.

set REPO_URL=https://github.com/cotafei/ekb_anon_bot.git
set TEMP_DIR=ekb_anon_bot_temp
set BACKUP_DIR=backups
set DATE=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set DATE=%DATE: =0%

cd /d %~dp0..

echo [1/10] Проверка Git...
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [❌] Git не установлен!
    echo Скачайте с https://git-scm.com/
    pause
    exit /b 1
)
echo [✅] Git найден
echo.

echo [2/10] Создание резервной копии...
if not exist %BACKUP_DIR% mkdir %BACKUP_DIR%
set BACKUP_FILE=%BACKUP_DIR%\pre_update_backup_%DATE%.tar.gz

if exist docker\docker-compose.yml (
    echo Останавливаю бота...
    cd docker && docker-compose stop bot >nul 2>&1 && cd ..
)

tar -czf %BACKUP_FILE% data\ logs\ .env 2>nul
if %errorlevel% equ 0 (
    echo [✅] Бэкап создан: %BACKUP_FILE%
) else (
    echo [⚠️] Не удалось создать бэкап
)
echo.

echo [3/10] Скачивание последней версии с GitHub...
if exist %TEMP_DIR% rmdir /s /q %TEMP_DIR%
git clone --depth 1 %REPO_URL% %TEMP_DIR%

if %errorlevel% neq 0 (
    echo [❌] Ошибка при скачивании!
    if exist docker\docker-compose.yml (
        cd docker && docker-compose start bot >nul 2>&1 && cd ..
    )
    pause
    exit /b 1
)
echo [✅] Репозиторий скачан
echo.

echo [4/10] Сохранение скрипта миграции...
if exist src\migrate_db.py (
    copy src\migrate_db.py migrate_db.py.bak >nul
    echo [✅] Скрипт миграции сохранен
) else (
    echo [⚠️] Скрипт миграции не найден
)
echo.

echo [5/10] Обновление файлов проекта...

REM src
if exist src rmdir /s /q src
move %TEMP_DIR%\src src >nul

REM восстанавливаем migrate_db.py
if exist migrate_db.py.bak (
    copy migrate_db.py.bak src\migrate_db.py >nul
    del migrate_db.py.bak
    echo [✅] Скрипт миграции восстановлен
)

REM docker
if exist docker rmdir /s /q docker
move %TEMP_DIR%\docker docker >nul

REM scripts
if exist scripts rmdir /s /q scripts
move %TEMP_DIR%\scripts scripts >nul
if exist scripts\update_from_github.bat del scripts\update_from_github.bat >nul 2>&1
copy %~f0 scripts\update_from_github.bat >nul

REM корневые файлы
copy %TEMP_DIR%\.env.example .env.example_new >nul 2>&1
copy %TEMP_DIR%\requirements.txt requirements.txt_new >nul 2>&1

if exist .env.example del .env.example
ren .env.example_new .env.example >nul 2>&1

if exist requirements.txt del requirements.txt
ren requirements.txt_new requirements.txt >nul 2>&1

echo [✅] Файлы обновлены
echo.

echo [6/10] Проверка .env файла...
if not exist .env (
    echo [⚠️] .env не найден, создаю из примера
    copy .env.example .env
    echo.
    echo [⚠️] ВНИМАНИЕ: Отредактируйте .env файл!
    echo    Укажите TOKEN, CHANNEL_ID, ADMINS
    echo.
) else (
    echo [✅] .env файл сохранен
)
echo.

echo [7/10] Запуск миграции базы данных...
cd src
python migrate_db.py
cd ..

if %errorlevel% equ 0 (
    echo [✅] Миграция БД успешно выполнена
) else (
    echo [❌] Ошибка при миграции БД!
)
echo.

echo [8/10] Запуск обновленного бота...
cd docker && docker-compose up -d --build && cd ..

if %errorlevel% equ 0 (
    echo [✅] Бот успешно обновлен и запущен!
    echo.
    echo 📊 Информация:
    echo   • Резервная копия: %BACKUP_FILE%
    echo   • Миграция БД: выполнена
    echo   • Логи: cd docker ^&^& docker-compose logs -f
) else (
    echo [❌] Ошибка при запуске бота!
)

echo [9/10] Очистка временных файлов...
if exist %TEMP_DIR% rmdir /s /q %TEMP_DIR%

echo.
echo [✅] Обновление завершено!
pause