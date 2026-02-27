import asyncio
import logging
from aiogram import Bot, Dispatcher, F
from aiogram.filters import Command
from aiogram.exceptions import TelegramNetworkError, TelegramRetryAfter

from config import TOKEN
from database import init_db
from handlers import *
from admin import *
from features import *  # Добавлен импорт features

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("bot.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

bot = Bot(token=TOKEN)
dp = Dispatcher()

# Инициализация базы данных
init_db()

# Регистрация обработчиков
dp.message.register(start_handler, Command("start"))  # из features.py
dp.message.register(help_handler, Command("help"))
dp.message.register(rules_handler, Command("rules"))
dp.message.register(stats_handler, Command("stats"))
dp.message.register(referral_handler, Command("referral"))  # из features.py
dp.message.register(daily_bonus_handler, Command("daily"))  # из features.py
dp.message.register(shop_handler, Command("shop"))  # из features.py
dp.message.register(admin_panel, Command("moderate"))
dp.message.register(admin_stats, Command("admin_stats"))
dp.message.register(post_handler, F.content_type.in_({'text', 'photo', 'video'}))
dp.callback_query.register(callback_handler)
dp.message.register(unknown_handler)

async def main():
    logger.info("🚀 Бот запускается...")
    
    # Добавляем задержку для инициализации
    await asyncio.sleep(5)
    
    # Бесконечный цикл с переподключением
    while True:
        try:
            logger.info("Подключение к Telegram API...")
            await dp.start_polling(bot)
            
        except TelegramNetworkError as e:
            logger.error(f"Сетевая ошибка: {e}. Переподключение через 30 секунд...")
            await asyncio.sleep(30)
            
        except TelegramRetryAfter as e:
            logger.warning(f"Лимит запросов: {e}. Ожидание {e.retry_after} секунд")
            await asyncio.sleep(e.retry_after)
            
        except Exception as e:
            logger.error(f"Неизвестная ошибка: {e}. Переподключение через 60 секунд...")
            await asyncio.sleep(60)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Бот остановлен вручную")
    except Exception as e:
        logger.error(f"Критическая ошибка: {e}")