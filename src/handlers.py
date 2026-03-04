"""
Обработчики команд и сообщений для пользователей
Содержит базовые команды и обработку новых постов
Версия: 1.1.2
"""

import time
from collections import defaultdict 

from aiogram import types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext

from filters import check_rules
from config import ADMINS, SUPPORT_CONTACT, POST_COOLDOWN_SECONDS
from admin import ModeratorStates
from database import add_post, get_user_stats, is_user_banned
import logging


logger = logging.getLogger(__name__)
_user_last_post = defaultdict(float)

async def help_handler(message: types.Message):
    """Обработчик команды /help - показывает справку по боту"""
    text = (
        "ℹ️ Помощь по боту:\n\n"
        "📝 Отправь текст, фото или видео с подписью для создания поста\n"
        "⏳ Посты проходят модерацию перед публикацией\n"
        "📊 /stats - твоя статистика\n"
        "📋 /rules - правила публикации\n"
        "💰 /referral - реферальная программа\n"
        "🎁 /daily - ежедневный бонус\n"
        "🛍 /shop - магазин привилегий\n"
        "❓ /help - эта справка\n\n"
        f"По всем вопросам: {SUPPORT_CONTACT}"
    )
    await message.answer(text)

async def rules_handler(message: types.Message):
    """Обработчик команды /rules - показывает правила публикации"""
    text = (
        "📋 Правила публикации:\n\n"
        "✅ Минимум 20 символов\n"
        "✅ Максимум 400 символов\n"
        "✅ Без мата и оскорблений\n"
        "✅ Без ссылок и контактов\n"
        "✅ Фото/видео должны быть адекватными\n"
        "✅ Контент должен соответствовать тематике\n\n"
        "❌ Нарушение правил = бан"
    )
    await message.answer(text)

async def post_handler(message: types.Message, state: FSMContext):
    """
    Обработчик новых постов от пользователей
    Принимает текст, фото, видео, проверяет правила и отправляет на модерацию
    """
    user_id = message.from_user.id
    now = time.time()
    
    try:
        # === RATE LIMITING (защита от спама) ===
        if now - _user_last_post[user_id] < POST_COOLDOWN_SECONDS:
            remaining = int(POST_COOLDOWN_SECONDS - (now - _user_last_post[user_id]))
            await message.answer(f"⏳ Слишком часто! Подождите {remaining} сек.")
            return
        _user_last_post[user_id] = now
        
        # === ПРОВЕРКА БАНА ===
        if is_user_banned(user_id):
            await message.answer("⛔ Вы забанены и не можете отправлять посты.")
            return

        # === ПРОВЕРКА РЕЖИМА МОДЕРАЦИИ ===
        current_state = await state.get_state()
        if current_state == ModeratorStates.waiting_for_reject_reason.state:
            return
        
        # === ОПРЕДЕЛЯЕМ ТЕКСТ КОНТЕНТА ===
        if message.text:
            text_content = message.text
        elif message.caption:
            text_content = message.caption
        else:
            text_content = ""
        
        # === ПРОВЕРКА НАЛИЧИЯ ТЕКСТА ДЛЯ МЕДИА ===
        if (message.photo or message.video) and not text_content:
            await message.answer("❌ К фото или видео нужна подпись (минимум 20 символов)")
            return
        
        # === ПРОВЕРКА РАЗМЕРА ВИДЕО ===
        if message.video and message.video.file_size > MAX_MEDIA_SIZE:
            await message.answer("❌ Видео слишком большое (макс. 20MB)")
            return


        # === ПРОВЕРКА РАЗМЕРА ФОТО ===
        if message.photo:
            file_info = await message.bot.get_file(message.photo[-1].file_id)
            if file_info.file_size > MAX_MEDIA_SIZE:
                await message.answer("❌ Фото слишком большое")
                return
        
        # === ПРОВЕРКА ПРАВИЛ ===
        ok, resp = check_rules(text_content)
        if not ok:
            await message.answer(f"⛔ {resp}")
            return
        
        # === ДОБАВЛЯЕМ ПОСТ В БАЗУ ===
        post_id = None
        if message.photo:
            file_id = message.photo[-1].file_id
            post_id = add_post(user_id, text_content, "photo", file_id)
        elif message.video:
            file_id = message.video.file_id
            post_id = add_post(user_id, text_content, "video", file_id)
        else:
            post_id = add_post(user_id, text_content)
        
        # === ОТВЕТ ПОЛЬЗОВАТЕЛЮ ===
        if post_id:
            await message.answer(
                "✅ Пост отправлен на модерацию!\n"
                f"📋 ID вашего поста: #{post_id}\n\n"
                "Ожидайте решения модератора. Обычно это занимает несколько часов."
            )
            logger.info(f"📝 Пользователь {user_id} отправил пост #{post_id}")
        else:
            await message.answer("❌ Ошибка при отправке поста. Возможно, вы забанены.")
        
    except Exception as e:
        logger.error(f"Ошибка в post_handler для пользователя {user_id}: {e}", exc_info=True)
        await message.answer("❌ Произошла ошибка при обработке поста. Попробуйте позже.")

async def cancel_handler(message: types.Message, state: FSMContext):
    """Обработчик команды /cancel - отмена текущего действия"""
    current_state = await state.get_state()
    
    if current_state == ModeratorStates.waiting_for_reject_reason.state:
        from admin import cancel_moderation
        await cancel_moderation(message, state)
    else:
        if current_state is None:
            await message.answer("❌ Нет активного действия для отмены")
        else:
            await state.clear()
            await message.answer("✅ Действие отменено")

async def skip_handler(message: types.Message, state: FSMContext):
    """
    Обработчик команды /skip - пропуск модерации (только для админов)
    Быстрый отказ без ввода причины
    """
    if message.from_user.id not in ADMINS:
        await message.answer("❌ У вас нет прав для этой команды")
        return
    
    current_state = await state.get_state()
    if current_state != ModeratorStates.waiting_for_reject_reason.state:
        await message.answer("❌ Нет активной модерации для пропуска")
        return
    
    from admin import skip_moderation
    await skip_moderation(message, message.bot, state)

async def unknown_handler(message: types.Message):
    """Обработчик неизвестных команд"""
    await message.answer("🤔 Не понимаю эту команду. Используйте /help для справки.")