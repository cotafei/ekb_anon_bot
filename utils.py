from database import *
from config import CHANNEL_ID
from aiogram import Bot
from aiogram.types import InputMediaPhoto, InputMediaVideo
import asyncio

async def publish_post(bot: Bot, post):
    try:
        post_id, user_id, content, media_type, media_id, status, created_at, moderated_at = post
        
        # Добавляем информацию о посте
        caption = f"{content}\n\n#екатеринбург #анонимно"
        
        if media_type == "photo":
            await bot.send_photo(
                chat_id=CHANNEL_ID,
                photo=media_id,
                caption=caption
            )
        elif media_type == "video":
            await bot.send_video(
                chat_id=CHANNEL_ID,
                video=media_id,
                caption=caption
            )
        else:
            await bot.send_message(
                chat_id=CHANNEL_ID,
                text=caption
            )
            
        return True
        
    except Exception as e:
        print(f"Error publishing post: {e}")
        return False

async def notify_user(bot: Bot, user_id: int, message: str):
    try:
        await bot.send_message(user_id, message)
    except:
        pass  # Пользователь заблокировал бота

async def cleanup_old_posts():
    """Очистка старых отклоненных постов"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM posts WHERE status='rejected' AND created_at < datetime('now', '-30 days')")
    conn.commit()
    conn.close()
