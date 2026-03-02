@echo off
chcp 65001 > nul
title EKB Anon Bot Launcher
cd /d %~dp0..

echo ========================================
echo    EKB Anon Bot v1.1.1 - Запуск на Windows
echo ========================================
echo.

if not exist data mkdir data
if not exist logs mkdir logs
if not exist backups mkdir backups

echo [✅] Директории созданы
echo.

if not exist .env (
    echo [❌] Файл .env не найден!
    echo.
    echo Создаю .env из примера...
    copy .env.example .env 2>nul
    echo.
    echo [⚠️] Отредактируйте файл .env и укажите:
    echo    - TOKEN
    echo    - CHANNEL_ID
    echo    - ADMINS
    echo.
    pause
    exit /b 1
)

where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [❌] Docker не найден!
    pause
    exit /b 1
)

echo [🚀] Запуск бота...
cd docker && docker-compose down 2>nul && docker-compose up -d --build
cd ..

echo.
echo [✅] Бот запущен!
echo.
echo [📊] Полезные команды:
echo   • Логи: cd docker ^&^& docker-compose logs -f
echo   • Остановка: scripts\stop.bat
echo   • Бэкап: scripts\backup.bat
echo   • Обновление: scripts\update_from_github.bat
echo.
pause