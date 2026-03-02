"""
Обработчики команд и сообщений для пользователей
Содержит базовые команды и обработку новых постов
Версия: 1.1.1
"""

from aiogram import types, F
from aiogram.filters import Command
from aiogram.types import ContentType
from aiogram.fsm.context import FSMContext

from filters import check_rules
from database import add_post, get_user_stats
from config import ADMINS
from admin import ModeratorStates

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
        "По всем вопросам: @C0taf31"
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

async def stats_handler(message: types.Message):
    """Обработчик команды /stats - базовая статистика пользователя"""
    approved, total = get_user_stats(message.from_user.id)
    
    text = (
        f"📊 Ваша статистика:\n\n"
        f"✅ Одобрено постов: {approved}\n"
        f"📨 Всего отправлено: {total}\n"
        f"📈 Процент успеха: {round((approved/total*100) if total > 0 else 0)}%\n\n"
        "Продолжайте в том же духе! 💪"
    )
    await message.answer(text)

async def post_handler(message: types.Message, state: FSMContext):
    """
    Обработчик новых постов от пользователей
    Принимает текст, фото, видео, проверяет правила и отправляет на модерацию
    """
    try:
        # Проверяем, не находится ли админ в режиме модерации
        current_state = await state.get_state()
        if current_state == ModeratorStates.waiting_for_reject_reason.state:
            return
        
        # Определяем текст контента
        if message.text:
            text_content = message.text
        elif message.caption:
            text_content = message.caption
        else:
            text_content = ""
        
        # Проверяем правила
        ok, resp = check_rules(text_content)
        if not ok:
            await message.answer(f"⛔ {resp}")
            return
        
        # Добавляем пост в базу
        if message.photo:
            file_id = message.photo[-1].file_id
            post_id = add_post(message.from_user.id, text_content, "photo", file_id)
        elif message.video:
            file_id = message.video.file_id
            post_id = add_post(message.from_user.id, text_content, "video", file_id)
        else:
            post_id = add_post(message.from_user.id, text_content)
        
        if post_id:
            await message.answer(
                "✅ Пост отправлен на модерацию!\n"
                f"📋 ID вашего поста: #{post_id}\n\n"
                "Ожидайте решения модератора. Обычно это занимает несколько часов."
            )
        else:
            await message.answer("❌ Ошибка при отправке поста. Возможно, вы забанены или слишком часто отправляете посты.")
        
    except Exception as e:
        await message.answer("❌ Произошла ошибка при обработке поста. Попробуйте позже.")
        print(f"Error in post_handler: {e}")

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