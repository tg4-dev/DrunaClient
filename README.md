# Druna Flutter client

Мобильный клиент Druna для iOS и Android. Работает с REST API из `context/FRONTEND_API.md`. Интерфейс переписывается по Figma: дизайн-система и журнал решений — в `docs/design-system.md`, текущее состояние — в `AGENTS.md`.

## Что сейчас в приложении

| Экран / сценарий | Данные | Состояния |
|---|---|---|
| Splash и восстановление сессии (старый UI) | secure storage, `POST /auth/renew-token` при 401 | restoring, offline, expired session |
| Регистрация и вход (старый UI) | `POST /auth/sign-up`, `POST /auth/sign-in` | validation, submitting, server error |
| Календарь: месяц, день, лист события | демо-события в памяти | — |
| Друзья (слева от календаря, свайп слева направо) | `/api/v1/friends/*` или демо (переключается в настройках) | loading, empty, error, search, заявки ✓/✕ |
| Настройки (справа от календаря, шестерёнка) | профиль, `GET /ping/`, refresh токена | демо-данные, «нет сети», замедление анимаций, выход |

Группы, профиль, события на сервере и уведомления есть в `DrunaRepository`, но их экраны ждут нового UI. Как они работали раньше — `docs/legacy/`.

Опросы, гостевые приглашения, push delivery и подключение Apple/Google/Outlook Calendar отсутствуют в текущем backend-контракте (`docs/backend-changes.md`). Приложение не имитирует успешное сохранение.

## Требования

- Flutter stable с Dart `>=3.8.1`
- Xcode для iOS и Android Studio/SDK для Android
- запущенный DrunaServer

## Запуск

```bash
flutter pub get
flutter run --dart-define-from-file=config/development.json
```

`development.json` настроен на iOS Simulator (`http://localhost:8000`). Для Android Emulator запусти так:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Для физического устройства укажи LAN IP машины с backend. Для production скопируй `config/production.example.json` в игнорируемый `config/production.json`, укажи реальный HTTPS URL и используй:

```bash
flutter build apk --release --dart-define-from-file=config/production.json
flutter build ipa --release --dart-define-from-file=config/production.json
```

HTTP разрешён только в Android debug manifest. Production должен использовать HTTPS. iOS разрешает локальную сеть для разработки, но release также следует собирать с HTTPS endpoint.

## Архитектура

```text
lib/
  app/             composition и состояние сессии
  core/            API client, config, secure storage, theme
  models/          доменные модели и DTO mapping
  repositories/    операции DrunaServer
  features/        auth, home, events, friends, groups, profile, notifications
  shared/ui/       кнопки, avatar, state panels, scaffold
```

`ApiClient` централизованно добавляет Bearer access token, разбирает `{data,error}`, выполняет один общий refresh для параллельных `401`, сохраняет ротированную пару и повторяет исходный запрос не более одного раза. Токены хранятся через `flutter_secure_storage` (Keychain на iOS, Keystore-backed storage на Android) и очищаются при ошибке refresh или выходе.

## Проверки

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Тесты покрывают success/error envelope, auth header, сохранение токенов, общий refresh для параллельных `401`, очистку невалидной сессии и welcome smoke flow.

Перед публикацией замените стандартные bundle/application identifiers и настройте release signing под аккаунты проекта.
