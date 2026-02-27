from aiogram import types, F
from aiogram.filters import Command
from config import ADMINS
from database import get_pending_posts, approve_post, reject_post, get_post_by_id, get_global_stats
from utils import publish_post
import asyncio

async def admin_panel(message: types.Message, bot):
    if message.from_user.id not in ADMINS:
        await message.answer("❌ Доступ запрещен")
        return
    
    posts = get_pending_posts()
    if not posts:
        await message.answer("✅ Нет постов на модерацию.")
        return
    
    await message.answer(f"📋 Постов на модерации: {len(posts)}")
    
    for post in posts:
        post_id, user_id, content, media_type, media_id, status, created_at, moderated_at = post
        
        kb = types.InlineKeyboardMarkup(inline_keyboard=[
            [
                types.InlineKeyboardButton(text="✅ Одобрить", callback_data=f"approve_{post_id}"),
                types.InlineKeyboardButton(text="❌ Отклонить", callback_data=f"reject_{post_id}")
            ],
            [
                types.InlineKeyboardButton(text="👀 Просмотреть", callback_data=f"view_{post_id}"),
                types.InlineKeyboardButton(text="⏸️ Отложить", callback_data=f"skip_{post_id}")
            ]
        ])
        
        caption = f"📝 Пост #{post_id}\n👤 User ID: {user_id}\n⏰ {created_at}\n\n{content}"
        
        try:
            if media_type == "photo":
                await bot.send_photo(
                    chat_id=message.chat.id,
                    photo=media_id,
                    caption=caption[:1024],
                    reply_markup=kb
                )
            elif media_type == "video":
                await bot.send_video(
                    chat_id=message.chat.id,
                    video=media_id,
                    caption=caption[:1024],
                    reply_markup=kb
                )
            else:
                await bot.send_message(
                    chat_id=message.chat.id,
                    text=caption,
                    reply_markup=kb
                )
            await asyncio.sleep(0.5)  # Задержка между сообщениями
        except Exception as e:
            await message.answer(f"❌ Ошибка отправки поста #{post_id}: {str(e)}")

async def admin_stats(message: types.Message):
    if message.from_user.id not in ADMINS:
        return
    
    users, posts, approved = get_global_stats()
    pending = len(get_pending_posts())
    
    text = (
        f"📊 Статистика бота:\n\n"
        f"👥 Пользователей: {users}\n"
        f"📨 Всего постов: {posts}\n"
        f"✅ Одобрено: {approved}\n"
        f"⏳ На модерации: {pending}\n"
        f"📊 Процент одобрения: {round((approved/posts*100) if posts > 0 else 0)}%"
    )
    
    await message.answer(text)

async def callback_handler(callback: types.CallbackQuery, bot):
    if callback.from_user.id not in ADMINS:
        await callback.answer("❌ Доступ запрещен")
        return
    
    data = callback.data
    
    try:
        if data.startswith("approve_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post and post[5] == 'pending':
                await publish_post(bot, post)
                approve_post(post_id)
                await callback.message.edit_reply_markup(reply_markup=None)
                await callback.message.answer(f"✅ Пост #{post_id} одобрен и опубликован")
                await callback.answer("Одобрено!")
            else:
                await callback.answer("Пост уже обработан")
                
        elif data.startswith("reject_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post and post[5] == 'pending':
                reject_post(post_id)
                await callback.message.edit_reply_markup(reply_markup=None)
                await callback.message.answer(f"❌ Пост #{post_id} отклонен")
                await callback.answer("Отклонено!")
            else:
                await callback.answer("Пост уже обработан")
                
        elif data.startswith("view_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post:
                status_emoji = "✅" if post[5] == 'approved' else "❌" if post[5] == 'rejected' else "⏳"
                text = (
                    f"📋 Информация о посте #{post_id}\n\n"
                    f"👤 User ID: {post[1]}\n"
                    f"📊 Статус: {status_emoji} {post[5]}\n"
                    f"⏰ Создан: {post[6]}\n"
                    f"🕒 Модерирован: {post[7] or 'Еще нет'}\n\n"
                    f"📝 Контент:\n{post[2]}"
                )
                await callback.answer(text, show_alert=True)
            else:
                await callback.answer("Пост не найден")
                
        elif data.startswith("skip_"):
            await callback.answer("Пост отложен")
            
    except Exception as e:
        await callback.answer("❌ Ошибка обработки")
        print(f"Error in callback handler: {e}")
