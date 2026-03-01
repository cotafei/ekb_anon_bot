"""
Конфигурационный файл бота EKB Anon Bot
Версия: 1.1.0
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Загружаем .env
load_dotenv()

# Корневые директории
BASE_DIR = Path(__file__).parent.parent  # Корень проекта
DATA_DIR = BASE_DIR / 'data'              # Папка для БД
LOG_DIR = BASE_DIR / 'logs'                # Папка для логов

# Создаем папки
DATA_DIR.mkdir(exist_ok=True, parents=True)
LOG_DIR.mkdir(exist_ok=True, parents=True)

# Токен бота (обязательно)
TOKEN = os.getenv('TOKEN')
if not TOKEN:
    raise ValueError("❌ TOKEN не найден в .env")

# ID канала (обязательно)
CHANNEL_ID = os.getenv('CHANNEL_ID')
if not CHANNEL_ID:
    raise ValueError("❌ CHANNEL_ID не найден в .env")
CHANNEL_ID = int(CHANNEL_ID)

# ID админов (обязательно)
ADMINS_STR = os.getenv('ADMINS')
if not ADMINS_STR:
    raise ValueError("❌ ADMINS не найдены в .env")
ADMINS = [int(x.strip()) for x in ADMINS_STR.split(',') if x.strip()]

# Путь к базе данных
DB_PATH = str(DATA_DIR / 'anon_ekb.db')

# Настройки постов
MAX_POST_LENGTH = 400      # Макс. символов
MIN_POST_LENGTH = 20       # Мин. символов
MAX_MEDIA_SIZE = 20 * 1024 * 1024  # 20MB

# Реферальная система
REFERRAL_BONUS = 50  # Монет за реферала