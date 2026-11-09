# Версии и релизы

## Номер версии

Версия живёт в одном месте — `version` в `pubspec.yaml`:

```yaml
version: 0.1.1+2
```

- **`0.1.1` — версия для людей** (SemVer `MAJOR.MINOR.PATCH`). На Android
  это `versionName`, на iOS — `CFBundleShortVersionString`.
- **`2` — номер сборки** (`versionCode` / `CFBundleVersion`). Растёт на 1 с
  каждой сборкой, которую кто-то получает, и никогда не сбрасывается — даже
  когда меняется версия.
- В `pubspec.yaml` — **только цифры**. App Store и TestFlight не принимают
  буквы в `CFBundleShortVersionString`, поэтому стадия (`alpha`) пишется в
  теге и названии релиза, а не здесь.

Какую цифру поднимать, пока версия `0.x`:

| Что изменилось | Пример |
|---|---|
| Исправления, мелкие правки вида | `0.1.1` → `0.1.2` |
| Новые возможности или заметная переделка интерфейса | `0.1.2` → `0.2.0` |
| Первый публичный релиз в сторах | `1.0.0` |

## Стадия

Сейчас — **alpha**: приложение в разработке, раздаётся тестерам вручную.
Название релиза — `Druna v0.1.1-alpha`. Дальше — `beta` (TestFlight и
закрытое тестирование Google Play), затем релиз без суффикса.

## Как выпустить версию

1. Поднять `version` в `pubspec.yaml`: версию по таблице выше, номер сборки
   на 1.
2. Записать изменения в `CHANGELOG.md` под новой версией с датой.
3. Пройти проверки из `AGENTS.md` («Перед сдачей») и release checklist из
   `docs/roadmap.md`.
4. Коммит `Release v0.1.1-alpha` и аннотированный тег на него:

   ```bash
   git tag -a v0.1.1-alpha -m "Druna v0.1.1-alpha"
   git push origin v0.1.1-alpha
   ```

5. Собрать с конфигурацией разработки:

   ```bash
   flutter build apk --release --dart-define-from-file=config/development.json
   flutter build ipa --dart-define-from-file=config/development.json
   ```

Коммиты, теги и пуш делает автор.

## История

| Версия | Сборка | Тег |
|---|---|---|
| 0.1.0-alpha | 1 | `v0.1.0-alpha` — поставить на коммит первой версии |
| 0.1.1-alpha | 2 | `v0.1.1-alpha` |
| 0.2.0-alpha | 3 | `v0.2.0-alpha` |
