# Druna Flutter client

Мобильный клиент Druna для iOS и Android: личные события, друзья и общее
свободное время. Backend — [DrunaServer](https://github.com/TG4-Dev/DrunaServer),
контракт API — `context/FRONTEND_API.md`.

Правила работы с репозиторием — `AGENTS.md`. Дизайн — `docs/design-system.md`.

## Запуск

Нужны Flutter stable (Dart `>=3.8.1`), Xcode, для Android — Android SDK.

```bash
flutter pub get
flutter run -d <DEVICE_ID> --dart-define-from-file=config/development.json
```

- Сервер на Mac: `scripts/dev_server.sh` поднимает DrunaServer в Docker на
  порту 22000 и прописывает адрес в `config/development.json`.
- Без сервера: `--dart-define-from-file=config/offline.json` (код из письма —
  `123456`).
- Android Emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:22000`.
- Production (`https://druna.tg4.dev`): скопируйте
  `config/production.example.json` в игнорируемый `config/production.json`.

Указывайте `-d`: без него Flutter может собрать desktop-версию.

## Проверки

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
