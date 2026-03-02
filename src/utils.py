"""
Утилиты для работы бота
Содержит вспомогательные функции: публикация в канал, уведомления, очистка
Версия: 1.1.1
"""

import sqlite3
import logging
from aiogram import Bot
from config import CHANNEL_ID, DB_PATH

logger = logging.getLogger(__name__)

async def publish_post(bot: Bot, post) -> bool:
    """
    Публикация поста в канал
    Принимает кортеж с данными поста, отправляет в канал с хэштегами
    Возвращает True при успехе, False при ошибке
    """
    try:
        # Распаковываем все 9 полей поста
        (post_id, user_id, content, media_type, media_id, 
         status, created_at, moderated_at, moderated_by) = post
        
        # Добавляем информацию о посте
        caption = f"{content}\n\n#екатеринбург #анонимно"
        
        if media_type == "photo":
            await bot.send_photo(
                chat_id=CHANNEL_ID,
                photo=media_id,
                caption=caption
            )
            logger.info(f"📸 Опубликовано фото #{post_id} в канал")
            
        elif media_type == "video":
            await bot.send_video(
                chat_id=CHANNEL_ID,
                video=media_id,
                caption=caption
            )
            logger.info(f"🎥 Опубликовано видео #{post_id} в канал")
            
        else:
            await bot.send_message(
                chat_id=CHANNEL_ID,
                text=caption
            )
            logger.info(f"📝 Опубликован текст #{post_id} в канал")
            
        return True
        
    except Exception as e:
        logger.error(f"❌ Ошибка публикации поста #{post_id if 'post_id' in locals() else 'unknown'}: {e}")
        return False

async def notify_user(bot: Bot, user_id: int, message: str):
    """
    Отправка уведомления пользователю
    Игнорирует ошибки если пользователь заблокировал бота
    """
    try:
        await bot.send_message(user_id, message)
        logger.info(f"📨 Уведомление отправлено пользователю {user_id}")
    except Exception as e:
        logger.warning(f"⚠️ Не удалось отправить уведомление пользователю {user_id}: {e}")

async def cleanup_old_posts():
    """
    Очистка старых отклоненных постов (старше 30 дней)
    Запускается по расписанию или вручную
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM posts WHERE status='rejected' AND created_at < datetime('now', '-30 days')"
        )
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        
        if deleted > 0:
            logger.info(f"🧹 Удалено {deleted} старых отклоненных постов")
            
    except Exception as e:
        logger.error(f"❌ Ошибка очистки старых постов: {e}")

async def get_post_stats() -> dict:
    """
    Получение расширенной статистики по постам
    Возвращает статистику по дням и по типам медиа
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Посты по дням (последние 7 дней)
        cursor.execute("""
            SELECT DATE(created_at), COUNT(*) 
            FROM posts 
            GROUP BY DATE(created_at) 
            ORDER BY DATE(created_at) DESC 
            LIMIT 7
        """)
        daily_stats = cursor.fetchall()
        
        # Статистика по типам медиа
        cursor.execute("""
            SELECT media_type, COUNT(*) 
            FROM posts 
            WHERE media_type IS NOT NULL 
            GROUP BY media_type
        """)
        media_stats = cursor.fetchall()
        
        conn.close()
        
        return {
            'daily': daily_stats,
            'media': media_stats
        }
        
    except Exception as e:
        logger.error(f"❌ Ошибка получения статистики: {e}")
        return {}