# Druna — что сделать дальше

Перенесено из `AGENTS.md` 2026-11-03. Порядок — по приоритету.

## P0 — до первой тестовой раздачи

1. Поднять актуальный DrunaServer и провести end-to-end smoke test всех endpoint
   на реальных данных; сверить фактические DTO с `context/FRONTEND_API.md`.
2. Добавить test/staging `API_BASE_URL` и тестового пользователя без хранения
   пароля в Git.
3. Bundle/application ID — `dev.tg4.druna` (iOS и Android `applicationId`;
   Kotlin-пакет и macOS остались `com.example`).
4. Настроить Apple Development Team, provisioning profile и проверить запуск на
   физическом iPhone.
5. Установить Android SDK, проверить debug build и запуск на Android Emulator и
   физическом устройстве.
6. Проверить адаптивность, клавиатуру, локальный HTTP/ATS и сетевые ошибки на
   нескольких размерах iPhone/Android.
7. Серверный вход по почте: endpoint из `docs/backend-changes.md` («Вход и
   регистрация по почте») и `ServerAuthFlowSource` на них. До этого в
   production войти нельзя.
8. Сохранение паролей системой: в iOS `webcredentials:druna.tg4.dev` уже
   есть; серверу — `apple-app-site-association` и `assetlinks.json`
   (`docs/backend-changes.md`). Проверить на физическом iPhone: Associated
   Domains требует платную команду Apple.

## P1 — качество продукта

1. Integration tests для auth, events, friends и groups с mock server.
2. Устойчивое периодическое обновление уведомлений и lifecycle handling;
   сейчас обновление основано на открытии экрана и ручном refresh.
3. Вернуть группы, профиль и события на сервере в новом UI
   (`docs/design-system.md`, §10.1). Подключить Sign in with Apple и Google
   (§9.9, правила провайдеров).
4. Accessibility labels, Dynamic Type/text scaling, contrast audit и
   локализация вместо строк, зашитых в виджеты.
5. Observability: безопасное логирование request ID, crash reporting и
   аналитика без записи токенов/персональных данных.
6. CI для format, analyze, tests и debug builds обеих платформ.

## P2 — после расширения backend

1. Push notifications и управление device token.
2. Calendar integrations: календарь устройства на клиенте есть (импорт и
   экспорт в «Druna», `lib/features/calendar_sync/`); нужна отправка
   занятости на сервер — `docs/backend-changes.md`. Проверить на
   физическом iPhone и Android.
3. Опросы, гостевые приглашения и связанные экраны.
4. Backend upload для аватаров вместо ручного URL.
5. Offline cache и оптимистичные обновления, если это подтвердит продукт.
6. Passkeys: сервер WebAuthn (`docs/backend-changes.md`), затем Flutter-плагин
   и UI по дизайну автора.

## Release checklist

- production API работает только через HTTPS;
- bundle/application IDs и display metadata финализированы;
- иконки, splash, privacy descriptions и store assets готовы;
- Apple/Google signing хранится вне репозитория;
- версия/build number обновлены;
- unit, widget, integration и device smoke tests проходят;
- проверены logout, истёкший access token, невалидный refresh token, offline,
  timeout, пустые списки и destructive confirmations;
- удалены debug endpoints и тестовые учётные данные (сейчас ping и проверка
  refresh в настройках видны и в production);
- подготовлены privacy policy и сведения App Store/Google Play.
