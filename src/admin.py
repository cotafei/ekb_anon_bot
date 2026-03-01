"""
Админ панель для модерации постов
Версия: 1.1.0
"""

from aiogram import types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from config import ADMINS
from database import get_pending_posts, approve_post, reject_post, get_post_by_id, get_global_stats
from utils import publish_post, notify_user
import asyncio

# Состояния для FSM (машина состояний)
class ModeratorStates(StatesGroup):
    waiting_for_reject_reason = State()

async def admin_panel(message: types.Message, bot, state: FSMContext):
    """Панель модерации"""
    if message.from_user.id not in ADMINS:
        await message.answer("❌ Доступ запрещен")
        return
    
    # Всегда очищаем состояние при входе в панель
    await state.clear()
    
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
        
        caption = (
            f"📝 Пост #{post_id}\n"
            f"👤 User ID: {user_id}\n"
            f"⏰ {created_at}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"{content}"
        )
        
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
            await asyncio.sleep(0.5)
        except Exception as e:
            await message.answer(f"❌ Ошибка отправки поста #{post_id}: {str(e)}")

async def admin_stats(message: types.Message):
    """Статистика бота для админов"""
    if message.from_user.id not in ADMINS:
        return
    
    users, posts, approved = get_global_stats()
    pending = len(get_pending_posts())
    
    text = (
        f"📊 Статистика бота\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👥 Пользователей: {users}\n"
        f"📨 Всего постов: {posts}\n"
        f"✅ Одобрено: {approved}\n"
        f"⏳ На модерации: {pending}\n"
        f"📊 Процент одобрения: {round((approved/posts*100) if posts > 0 else 0)}%\n"
        f"━━━━━━━━━━━━━━━━━━━━━━"
    )
    
    await message.answer(text)

async def callback_handler(callback: types.CallbackQuery, bot, state: FSMContext):
    """Обработка нажатий на кнопки"""
    if callback.from_user.id not in ADMINS:
        await callback.answer("❌ Доступ запрещен")
        return
    
    data = callback.data
    
    try:
        if data.startswith("approve_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post and post[5] == 'pending':
                success = await publish_post(bot, post)
                
                if success:
                    approve_post(post_id)
                    
                    user_id = post[1]
                    await notify_user(
                        bot, 
                        user_id, 
                        f"✅ Ваш пост #{post_id} одобрен и опубликован в канале!"
                    )
                    
                    await callback.message.edit_reply_markup(reply_markup=None)
                    await callback.message.answer(f"✅ Пост #{post_id} одобрен и опубликован")
                    await callback.answer("✅ Одобрено!")
                    
                    # Показываем оставшиеся посты
                    pending = get_pending_posts()
                    if pending:
                        await callback.message.answer(
                            f"⏳ Осталось постов: {len(pending)}\n"
                            f"Используйте /moderate для продолжения"
                        )
                else:
                    await callback.answer("❌ Ошибка публикации в канал")
            else:
                await callback.answer("⏳ Пост уже обработан")
                
        elif data.startswith("reject_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post and post[5] == 'pending':
                # Проверяем, не обрабатываем ли уже другой пост
                current_state = await state.get_state()
                if current_state == ModeratorStates.waiting_for_reject_reason.state:
                    await callback.answer("⚠️ Сначала завершите текущую модерацию")
                    return
                
                # Сохраняем ID поста в состоянии
                await state.update_data(reject_post_id=post_id)
                await state.set_state(ModeratorStates.waiting_for_reject_reason)
                
                # Запрашиваем причину отказа
                await callback.message.answer(
                    f"📝 Напишите причину отказа для поста #{post_id}\n"
                    f"(можно написать что угодно, даже одно слово)\n"
                    f"Или используйте /cancel для отмены"
                )
                
                await callback.answer("⏳ Введите причину отказа...")
                await callback.message.edit_reply_markup(reply_markup=None)
            else:
                await callback.answer("⏳ Пост уже обработан")
                
        elif data.startswith("view_"):
            post_id = int(data.split("_")[1])
            post = get_post_by_id(post_id)
            
            if post:
                status_emoji = "✅" if post[5] == 'approved' else "❌" if post[5] == 'rejected' else "⏳"
                text = (
                    f"📋 Информация о посте #{post_id}\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
                    f"👤 User ID: {post[1]}\n"
                    f"📊 Статус: {status_emoji} {post[5]}\n"
                    f"⏰ Создан: {post[6]}\n"
                    f"🕒 Модерирован: {post[7] or 'Еще нет'}\n\n"
                    f"📝 Контент:\n{post[2]}"
                )
                await callback.answer(text, show_alert=True)
            else:
                await callback.answer("❌ Пост не найден")
                
        elif data.startswith("skip_"):
            await callback.answer("⏸️ Пост отложен")
            
    except Exception as e:
        await callback.answer("❌ Ошибка обработки")
        print(f"Error in callback handler: {e}")

async def process_reject_reason(message: types.Message, bot, state: FSMContext):
    """Обработка причины отказа - принимает ЛЮБОЙ текст"""
    if message.from_user.id not in ADMINS:
        return
    
    # Проверяем, находимся ли мы в состоянии ожидания причины
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        return
    
    # Получаем данные из состояния
    data = await state.get_data()
    post_id = data.get('reject_post_id')
    
    if not post_id:
        await state.clear()
        return
    
    post = get_post_by_id(post_id)
    if not post or post[5] != 'pending':
        await message.answer("❌ Пост уже обработан")
        await state.clear()
        return
    
    # Получаем причину - принимаем ЛЮБОЙ текст
    reason = message.text.strip()
    
    # Если причина пустая (редкий случай)
    if not reason:
        reason = "причина не указана"
    
    # Обработка команды "пропустить"
    if reason.lower() in ['пропустить', 'пропусти', 'skip', '-']:
        reason = "не соответствует правилам"
    
    # Для очень коротких причин (типа "хуйня") - всё равно принимаем
    # Никаких проверок на длину!
    
    # Отклоняем пост
    reject_post(post_id)
    
    # Уведомляем пользователя
    user_id = post[1]
    await notify_user(
        bot, 
        user_id, 
        f"❌ Ваш пост #{post_id} отклонен модератором.\n"
        f"📝 Причина: {reason}"
    )
    
    await message.answer(f"✅ Пост #{post_id} отклонен\nПричина: {reason}")
    
    # Очищаем состояние
    await state.clear()
    
    # Показываем оставшиеся посты
    pending = get_pending_posts()
    if pending:
        await message.answer(
            f"⏳ Осталось постов: {len(pending)}\n"
            f"Используйте /moderate для продолжения"
        )
    else:
        await message.answer("✅ Все посты обработаны!")

async def cancel_moderation(message: types.Message, state: FSMContext):
    """Отмена текущей модерации (команда /cancel)"""
    if message.from_user.id not in ADMINS:
        return
    
    # Проверяем, находимся ли мы в состоянии ожидания причины
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        await message.answer("❌ Нет активной модерации для отмены")
        return
    
    # Получаем данные из состояния
    data = await state.get_data()
    post_id = data.get('reject_post_id')
    
    # Очищаем состояние
    await state.clear()
    
    if post_id:
        await message.answer(
            f"✅ Модерация поста #{post_id} отменена\n"
            f"Пост остался в очереди. Используйте /moderate для продолжения"
        )
    else:
        await message.answer("✅ Модерация отменена")

async def skip_moderation(message: types.Message, bot, state: FSMContext):
    """Быстрый пропуск без причины (команда /skip)"""
    if message.from_user.id not in ADMINS:
        return
    
    # Проверяем, находимся ли мы в состоянии ожидания причины
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        await message.answer("❌ Нет активной модерации для пропуска")
        return
    
    # Получаем данные из состояния
    data = await state.get_data()
    post_id = data.get('reject_post_id')
    
    if not post_id:
        await state.clear()
        return
    
    post = get_post_by_id(post_id)
    if not post or post[5] != 'pending':
        await message.answer("❌ Пост уже обработан")
        await state.clear()
        return
    
    # Отклоняем с причиной по умолчанию
    reason = "не соответствует правилам"
    reject_post(post_id)
    
    # Уведомляем пользователя
    user_id = post[1]
    await notify_user(
        bot, 
        user_id, 
        f"❌ Ваш пост #{post_id} отклонен модератором.\n"
        f"📝 Причина: {reason}"
    )
    
    await message.answer(f"✅ Пост #{post_id} отклонен (без указания причины)")
    
    # Очищаем состояние
    await state.clear()
    
    # Показываем оставшиеся посты
    pending = get_pending_posts()
    if pending:
        await message.answer(
            f"⏳ Осталось постов: {len(pending)}\n"
            f"Используйте /moderate для продолжения"
        )
    else:
        await message.answer("✅ Все посты обработаны!")