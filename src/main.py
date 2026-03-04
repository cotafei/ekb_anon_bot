"""
EKB Anon Bot - Главный модуль приложения
Анонимный бот для публикации постов в Telegram канал с модерацией
Версия: 1.1.2
"""

import asyncio
import logging
import os
import sys
from pathlib import Path

from aiogram import Bot, Dispatcher, F
from aiogram.filters import Command, StateFilter
from aiogram.exceptions import TelegramNetworkError, TelegramRetryAfter
from aiogram.types import BotCommand
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.fsm.storage.memory import MemoryStorage

# Добавляем путь к src для импортов
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import TOKEN, ADMINS
from database import init_db
from handlers import (
    help_handler, rules_handler,
    post_handler, unknown_handler, cancel_handler, skip_handler
)
from admin import (
    admin_panel, admin_stats, callback_handler, 
    process_reject_reason, ModeratorStates,
    cancel_moderation, skip_moderation
)
from features import (
    start_handler, referral_handler, 
    daily_bonus_handler, shop_handler, stats_handler
)

# ============================================================
# КОНСТАНТЫ И ПУТИ
# ============================================================

class Paths:
    """Управление путями к директориям"""
    BASE_DIR = Path(__file__).parent.parent
    LOG_DIR = BASE_DIR / 'logs'
    DATA_DIR = BASE_DIR / 'data'
    
    @classmethod
    def ensure_dirs(cls) -> None:
        """Создание необходимых директорий"""
        cls.LOG_DIR.mkdir(exist_ok=True, parents=True)
        cls.DATA_DIR.mkdir(exist_ok=True, parents=True)
        
        log_file = cls.LOG_DIR / 'bot.log'
        if not log_file.exists():
            log_file.touch(exist_ok=True)
        
        print("✅ Директории созданы:")
        print(f"   📁 Данные: {cls.DATA_DIR}")
        print(f"   📁 Логи: {cls.LOG_DIR}")

# Создаем директории до всего
Paths.ensure_dirs()

# ============================================================
# НАСТРОЙКА ЛОГИРОВАНИЯ
# ============================================================

class BotLogger:
    """Настройка логирования с поддержкой Unicode"""
    
    @staticmethod
    def setup() -> logging.Logger:
        """Настройка логирования"""
        log_file = Paths.LOG_DIR / 'bot.log'
        
        formatter = logging.Formatter(
            '%(asctime)s | %(levelname)-8s | %(name)s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        file_handler = logging.FileHandler(log_file, encoding='utf-8', mode='a')
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.INFO)
        
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        console_handler.setLevel(logging.INFO)
        
        root_logger = logging.getLogger()
        root_logger.setLevel(logging.INFO)
        root_logger.handlers.clear()
        root_logger.addHandler(file_handler)
        root_logger.addHandler(console_handler)
        
        # Уменьшаем подробность логов от библиотек
        logging.getLogger('aiogram').setLevel(logging.WARNING)
        logging.getLogger('aiohttp').setLevel(logging.WARNING)
        logging.getLogger('asyncio').setLevel(logging.WARNING)
        
        return logging.getLogger(__name__)

# ============================================================
# ОСНОВНОЙ КЛАСС БОТА
# ============================================================

class EKBAnonBot:
    """Основной класс бота"""
    
    def __init__(self):
        self.bot: Bot = None
        self.dp: Dispatcher = None
        self.logger = logging.getLogger(__name__)
        self.storage = MemoryStorage()
        
    async def check_other_instances(self) -> bool:
        """Проверяет, не запущен ли бот в другом месте (вебхук)"""
        try:
            webhook_info = await self.bot.get_webhook_info()
            if webhook_info.url:
                self.logger.warning("⚠️ Обнаружен вебхук! Удаляю...")
                await self.bot.delete_webhook()
                await asyncio.sleep(1)
            return True
        except Exception as e:
            self.logger.error(f"❌ Ошибка проверки: {e}")
            return False
        
    async def initialize(self) -> None:
        """Инициализация компонентов бота"""
        self.logger.info("🔧 Инициализация компонентов...")
        
        self.logger.info(f"📁 Директория данных: {Paths.DATA_DIR}")
        self.logger.info(f"📁 Директория логов: {Paths.LOG_DIR}")
        
        # Создаем экземпляр бота
        self.bot = Bot(
            token=TOKEN,
            default=DefaultBotProperties(
                parse_mode=ParseMode.HTML
            )
        )
        
        await self.check_other_instances()
        
        # Создаем диспетчер с хранилищем состояний
        self.dp = Dispatcher(storage=self.storage)
        
        # Инициализируем базу данных
        try:
            init_db()
            self.logger.info("💾 База данных инициализирована")
        except Exception as e:
            self.logger.error(f"❌ Ошибка инициализации БД: {e}")
            raise
        
        # Регистрируем обработчики
        await self._register_handlers()
        
        # Устанавливаем команды
        await self._set_commands()
        
        bot_info = await self.bot.get_me()
        self.logger.info(f"🤖 Бот @{bot_info.username} (ID: {bot_info.id})")
        
    async def _register_handlers(self) -> None:
        """Регистрация всех обработчиков сообщений"""
        self.logger.info("📝 Регистрация обработчиков...")
        
        # ===== КОМАНДЫ УПРАВЛЕНИЯ (ВЫСШИЙ ПРИОРИТЕТ) =====
        self.dp.message.register(cancel_handler, Command("cancel"))
        self.dp.message.register(skip_handler, Command("skip"))
        
        # ===== FSM СОСТОЯНИЯ =====
        self.dp.message.register(
            process_reject_reason, 
            StateFilter(ModeratorStates.waiting_for_reject_reason)
        )
        
        # ===== АДМИНСКИЕ КОМАНДЫ =====
        self.dp.message.register(
            admin_panel, 
            Command("moderate"),
            lambda message: message.from_user.id in ADMINS
        )
        
        self.dp.message.register(
            admin_stats, 
            Command("admin_stats"),
            lambda message: message.from_user.id in ADMINS
        )
        
        # ===== ОБЫЧНЫЕ КОМАНДЫ =====
        self.dp.message.register(start_handler, Command("start"))
        self.dp.message.register(help_handler, Command("help"))
        self.dp.message.register(rules_handler, Command("rules"))
        self.dp.message.register(stats_handler, Command("stats"))
        self.dp.message.register(referral_handler, Command("referral"))
        self.dp.message.register(daily_bonus_handler, Command("daily"))
        self.dp.message.register(shop_handler, Command("shop"))
        
        # ===== ОБРАБОТКА КОНТЕНТА =====
        self.dp.message.register(
            post_handler, 
            F.content_type.in_({'text', 'photo', 'video'})
        )

        # ===== CALLBACK ЗАПРОСЫ =====
        self.dp.callback_query.register(callback_handler)
        
        # ===== ВСЕ ОСТАЛЬНЫЕ СООБЩЕНИЯ =====
        self.dp.message.register(unknown_handler)
        
        handlers_count = len(self.dp.message.handlers)
        self.logger.info(f"✅ Зарегистрировано {handlers_count} обработчиков")
        
    async def _set_commands(self) -> None:
        """Установка команд в интерфейсе Telegram"""
        self.logger.info("⌨️ Установка команд...")
        
        # Общие команды для всех пользователей
        user_commands = [
            BotCommand(command="start", description="🚀 Запустить бота"),
            BotCommand(command="help", description="❓ Помощь"),
            BotCommand(command="stats", description="📊 Моя статистика"),
            BotCommand(command="rules", description="📋 Правила"),
            BotCommand(command="referral", description="👥 Рефералы"),
            BotCommand(command="daily", description="🎁 Ежедневный бонус"),
            BotCommand(command="shop", description="🛍 Магазин"),
            BotCommand(command="cancel", description="❌ Отменить действие"),
        ]
        
        await self.bot.set_my_commands(user_commands)
        
        # Дополнительные команды для админов
        if ADMINS:
            admin_commands = user_commands + [
                BotCommand(command="moderate", description="🛡 Модерация"),
                BotCommand(command="admin_stats", description="📈 Статистика бота"),
                BotCommand(command="skip", description="⏭ Пропустить модерацию"),
            ]
            
            for admin_id in ADMINS:
                try:
                    await self.bot.set_my_commands(
                        admin_commands,
                        scope={"type": "chat", "chat_id": admin_id}
                    )
                    self.logger.info(f"   👑 Админ {admin_id}")
                except Exception as e:
                    self.logger.error(f"   ❌ Ошибка для админа {admin_id}: {e}")
        
        self.logger.info("✅ Команды установлены")
        
    async def start(self) -> None:
        """Запуск бота"""
        self.logger.info("=" * 60)
        self.logger.info("🚀 ЗАПУСК БОТА")
        self.logger.info("=" * 60)
        
        try:
            await self.initialize()
            await self._start_polling()
            
        except Exception as e:
            self.logger.critical(f"💥 Критическая ошибка: {e}", exc_info=True)
            await self.shutdown()
            raise
            
    async def _start_polling(self) -> None:
        """Запуск polling с обработкой ошибок"""
        self.logger.info("🔄 Запуск polling...")
        self.logger.info("⏳ Бот ожидает сообщений...")
        self.logger.info("📊 Нажмите Ctrl+C для остановки")
        
        try:
            # start_polling сам обрабатывает многие ошибки и переподключается
            await self.dp.start_polling(
                self.bot,
                allowed_updates=['message', 'callback_query'],
                handle_signals=True,
                close_bot_session=True,
            )
        except TelegramNetworkError as e:
            self.logger.error(f"🌐 Критическая сетевая ошибка: {e}")
            self.logger.info("🔄 Попробуйте перезапустить бота через несколько минут...")
        except TelegramRetryAfter as e:
            self.logger.error(f"⏰ Превышен лимит запросов: {e}")
        except asyncio.CancelledError:
            self.logger.info("⚠️ Задача отменена")
        except KeyboardInterrupt:
            self.logger.info("🛑 Получен сигнал остановки")
        except Exception as e:
            self.logger.error(f"❌ Неизвестная ошибка в polling: {e}", exc_info=True)
        finally:
            self.logger.info("🛑 Polling остановлен.")
                
    async def shutdown(self) -> None:
        """Корректное завершение работы"""
        self.logger.info("🛑 Завершение работы...")
        
        if self.bot:
            await self.bot.session.close()
            self.logger.info("✅ Сессия бота закрыта")
            
        if self.storage:
            await self.storage.close()
            self.logger.info("✅ Хранилище состояний закрыто")
            
        self.logger.info("👋 Бот остановлен")

# ============================================================
# ОБРАБОТКА ГЛОБАЛЬНЫХ ИСКЛЮЧЕНИЙ
# ============================================================

def setup_exception_handling() -> None:
    """Настройка обработки необработанных исключений"""
    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
            
        logger = logging.getLogger(__name__)
        logger.critical("💥 Необработанное исключение", 
                       exc_info=(exc_type, exc_value, exc_traceback))
        
    sys.excepthook = handle_exception

# ============================================================
# ТОЧКА ВХОДА
# ============================================================

async def main() -> None:
    """Точка входа в приложение"""
    logger = BotLogger.setup()
    
    print("\n" + "="*60)
    print("📦 EKB Anon Bot v1.1.2".center(60))
    print("="*60 + "\n")
    
    if not TOKEN:
        logger.critical("❌ Токен не найден! Проверьте .env файл")
        sys.exit(1)
    
    setup_exception_handling()
    
    bot = EKBAnonBot()
    
    try:
        await bot.start()
    except KeyboardInterrupt:
        logger.info("🛑 Бот остановлен пользователем")
    except Exception as e:
        logger.critical(f"💥 Фатальная ошибка: {e}", exc_info=True)
        sys.exit(1)
    finally:
        await bot.shutdown()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n" + "="*60)
        print("🛑 Бот остановлен".center(60))
        print("="*60 + "\n")
        pass
    except Exception as e:
        logging.basicConfig(level=logging.CRITICAL)
        logging.critical(f"💥 Критическая ошибка запуска: {e}", exc_info=True)
        sys.exit(1)