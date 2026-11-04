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

- Сервер: `https://druna.tg4.dev` (локально сервер не поднимаем).
- Демо-версия без сервера — переключатель в настройках «Для разработчика»
  (`DEMO_DATA` в `config/development.json` включает её при первом запуске).

Указывайте `-d`: без него Flutter может собрать desktop-версию.

## Проверки

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
