@echo off
chcp 65001 > nul
title EKB Anon Bot Backup
cd /d %~dp0..

echo ========================================
echo    Создание резервной копии
echo ========================================
echo.

set BACKUP_DIR=backups
set DATE=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set DATE=%DATE: =0%
set BACKUP_FILE=%BACKUP_DIR%\ekb_bot_backup_%DATE%.tar.gz

if not exist %BACKUP_DIR% mkdir %BACKUP_DIR%

echo [1/4] Проверка директорий...
if not exist data (
    echo [❌] Директория data не найдена!
    pause
    exit /b 1
)

echo [2/4] Остановка бота...
cd docker && docker-compose stop bot >nul 2>&1
cd ..

echo [3/4] Создание архива...
tar -czf %BACKUP_FILE% data\ logs\ 2>nul

if %errorlevel% equ 0 (
    echo [✅] Бэкап создан: %BACKUP_FILE%
    
    echo [4/4] Запуск бота...
    cd docker && docker-compose start bot >nul 2>&1
    cd ..
    
    echo.
    echo [✅] Резервное копирование завершено
) else (
    echo [❌] Ошибка при создании бэкапа!
    cd docker && docker-compose start bot >nul 2>&1
    cd ..
    pause
    exit /b 1
)

pause
pause