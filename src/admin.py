"""
Админ панель для модерации постов
Версия: 1.1.2
"""

from aiogram import types
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from config import ADMINS
from database import get_pending_posts, approve_post, reject_post, get_post_by_id, get_global_stats
from utils import publish_post, notify_user
import asyncio
import logging

logger = logging.getLogger(__name__)

class ModeratorStates(StatesGroup):
    """Состояния для FSM при модерации"""
    waiting_for_reject_reason = State()

# Словарь для блокировки постов (защита от двойной модерации)
_post_locks = {}

async def admin_panel(message: types.Message, bot, state: FSMContext):
    """
    Панель модерации для админов
    Показывает все ожидающие посты с кнопками управления
    """
    if message.from_user.id not in ADMINS:
        await message.answer("❌ Доступ запрещен")
        return
    
    await state.clear()
    
    try:
        posts = get_pending_posts()
        if not posts:
            await message.answer("✅ Нет постов на модерацию.")
            return
        
        await message.answer(f"📋 Постов на модерации: {len(posts)}")
        
        for post in posts:
            await send_post_to_moderator(message, bot, post)
            await asyncio.sleep(0.3)
            
    except Exception as e:
        logger.error(f"Ошибка в панели модерации: {e}")
        await message.answer("❌ Произошла ошибка при загрузке постов")

async def send_post_to_moderator(message: types.Message, bot, post):
    """Отправка одного поста модератору с инлайн-кнопками"""
    post_id = None
    try:
        # Распаковываем все поля поста (9 полей)
        (post_id, user_id, content, media_type, media_id, 
         status, created_at, moderated_at, moderated_by) = post
        
        # Создаем инлайн-кнопки для управления постом
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
    except Exception as e:
        error_msg = f"❌ Ошибка отправки поста"
        if post_id:
            error_msg += f" #{post_id}"
        error_msg += f": {str(e)}"
        await message.answer(error_msg)
        logger.error(f"Ошибка отправки поста {post_id if post_id else 'unknown'}: {e}")

async def admin_stats(message: types.Message):
    """Статистика бота для админов"""
    if message.from_user.id not in ADMINS:
        return
    
    try:
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
    except Exception as e:
        logger.error(f"Ошибка получения статистики: {e}")
        await message.answer("❌ Ошибка получения статистики")

async def callback_handler(callback: types.CallbackQuery, bot, state: FSMContext):
    """Обработка нажатий на инлайн-кнопки"""
    if callback.from_user.id not in ADMINS:
        await callback.answer("❌ Доступ запрещен")
        return
    
    data = callback.data
    
    try:
        if data.startswith("approve_"):
            post_id = int(data.split("_")[1])
            await handle_approve(callback, bot, post_id)
            
        elif data.startswith("reject_"):
            post_id = int(data.split("_")[1])
            await handle_reject(callback, state, post_id)
            
        elif data.startswith("view_"):
            post_id = int(data.split("_")[1])
            await handle_view(callback, post_id)
            
        elif data.startswith("skip_"):
            await callback.answer("⏸️ Пост отложен")
            
    except Exception as e:
        logger.error(f"Ошибка в callback_handler: {e}")
        await callback.answer("❌ Ошибка обработки")

async def handle_approve(callback: types.CallbackQuery, bot, post_id: int):
    """Обработка одобрения поста"""
    if post_id in _post_locks:
        await callback.answer("⚠️ Пост уже обрабатывается")
        return
    
    _post_locks[post_id] = callback.from_user.id
    
    try:
        post = get_post_by_id(post_id)
        
        if not post or post[5] != 'pending':
            await callback.answer("⏳ Пост уже обработан")
            return
        
        success = await publish_post(bot, post)
        
        if success:
            # Передаём ID модератора в функцию одобрения
            if approve_post(post_id, callback.from_user.id):
                user_id = post[1]
                await notify_user(
                    bot, 
                    user_id, 
                    f"✅ Ваш пост #{post_id} одобрен и опубликован в канале!"
                )
                
                await callback.message.edit_reply_markup(reply_markup=None)
                await callback.message.answer(f"✅ Пост #{post_id} одобрен и опубликован")
                await callback.answer("✅ Одобрено!")
                
                pending = get_pending_posts()
                if pending:
                    await callback.message.answer(
                        f"⏳ Осталось постов: {len(pending)}\n"
                        f"Используйте /moderate для продолжения"
                    )
            else:
                await callback.message.answer(f"❌ Не удалось одобрить пост #{post_id} (возможно, он уже обработан).")
        else:
            await callback.answer("❌ Ошибка публикации в канал")
    finally:
        _post_locks.pop(post_id, None)

async def handle_reject(callback: types.CallbackQuery, state: FSMContext, post_id: int):
    """Обработка отклонения поста (запрос причины)"""
    if post_id in _post_locks:
        await callback.answer("⚠️ Пост уже обрабатывается")
        return
    
    _post_locks[post_id] = callback.from_user.id
    
    try:
        post = get_post_by_id(post_id)
        
        if not post or post[5] != 'pending':
            await callback.answer("⏳ Пост уже обработан")
            return
        
        current_state = await state.get_state()
        if current_state == ModeratorStates.waiting_for_reject_reason.state:
            await callback.answer("⚠️ Сначала завершите текущую модерацию")
            return
        
        await state.update_data(reject_post_id=post_id)
        await state.set_state(ModeratorStates.waiting_for_reject_reason)
        
        await callback.message.answer(
            f"📝 Напишите причину отказа для поста #{post_id}\n"
            f"(можно написать что угодно, даже одно слово)\n"
            f"Или используйте /cancel для отмены"
        )
        
        await callback.answer("⏳ Введите причину отказа...")
        await callback.message.edit_reply_markup(reply_markup=None)
        
    except Exception as e:
        logger.error(f"Ошибка при отклонении: {e}")
        _post_locks.pop(post_id, None)
        await callback.answer("❌ Ошибка")

async def handle_view(callback: types.CallbackQuery, post_id: int):
    """Просмотр подробной информации о посте"""
    post = get_post_by_id(post_id)
    
    if post:
        status_emoji = "✅" if post[5] == 'approved' else "❌" if post[5] == 'rejected' else "⏳"
        
        # Добавляем информацию о модераторе
        moderated_info = ""
        if post[8]:  # moderated_by
            moderated_info = f"👮 Модератор: {post[8]}\n"
        
        text = (
            f"📋 Информация о посте #{post_id}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"👤 User ID: {post[1]}\n"
            f"📊 Статус: {status_emoji} {post[5]}\n"
            f"⏰ Создан: {post[6]}\n"
            f"🕒 Модерирован: {post[7] or 'Еще нет'}\n"
            f"{moderated_info}"
            f"📝 Контент:\n{post[2]}"
        )
        await callback.answer(text, show_alert=True, cache_time=0)
    else:
        await callback.answer("❌ Пост не найден")

async def process_reject_reason(message: types.Message, bot, state: FSMContext):
    """Обработка введенной причины отказа"""
    if message.from_user.id not in ADMINS:
        return
    
    post_id = None
    
    try:
        current_state = await state.get_state()
        if current_state != ModeratorStates.waiting_for_reject_reason.state:
            return
        
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
        
        reason = message.text.strip()
        if not reason:
            reason = "причина не указана"
        
        if reason.lower() in ['пропустить', 'пропусти', 'skip', '-']:
            reason = "не соответствует правилам"
        
        # Передаём ID модератора в функцию отклонения
        if reject_post(post_id, message.from_user.id):
            user_id = post[1]
            await notify_user(
                bot, 
                user_id, 
                f"❌ Ваш пост #{post_id} отклонен модератором.\n"
                f"📝 Причина: {reason}"
            )
            
            await message.answer(f"✅ Пост #{post_id} отклонен\nПричина: {reason}")
            
            pending = get_pending_posts()
            if pending:
                await message.answer(
                    f"⏳ Осталось постов: {len(pending)}\n"
                    f"Используйте /moderate для продолжения"
                )
            else:
                await message.answer("✅ Все посты обработаны!")
        else:
            await message.answer("❌ Не удалось отклонить пост")
    
    except Exception as e:
        logger.error(f"Ошибка при отклонении поста: {e}")
        await message.answer("❌ Произошла ошибка")
    finally:
        await state.clear()
        if post_id:
            _post_locks.pop(post_id, None)

async def cancel_moderation(message: types.Message, state: FSMContext):
    """Отмена текущей модерации (команда /cancel)"""
    if message.from_user.id not in ADMINS:
        return
    
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        await message.answer("❌ Нет активной модерации для отмены")
        return
    
    data = await state.get_data()
    post_id = data.get('reject_post_id')
    
    await state.clear()
    if post_id:
        _post_locks.pop(post_id, None)
    
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
    
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        await message.answer("❌ Нет активной модерации для пропуска")
        return
    
    post_id = None
    
    try:
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
        
        reason = "не соответствует правилам"
        # Передаём ID модератора
        if reject_post(post_id, message.from_user.id):
            user_id = post[1]
            await notify_user(
                bot, 
                user_id, 
                f"❌ Ваш пост #{post_id} отклонен модератором.\n"
                f"📝 Причина: {reason}"
            )
            
            await message.answer(f"✅ Пост #{post_id} отклонен (без указания причины)")
            
            pending = get_pending_posts()
            if pending:
                await message.answer(
                    f"⏳ Осталось постов: {len(pending)}\n"
                    f"Используйте /moderate для продолжения"
                )
            else:
                await message.answer("✅ Все посты обработаны!")
    
    except Exception as e:
        logger.error(f"Ошибка в skip_moderation: {e}")
        await message.answer("❌ Произошла ошибка")
    finally:
        await state.clear()
        if post_id:
            _post_locks.pop(post_id, None)