# DrunaClient — руководство для разработчиков и AI-агентов

Этот файл описывает текущее состояние Flutter-клиента Druna, правила работы с
репозиторием, локальный запуск и оставшиеся задачи. Перед изменениями также
прочитайте `README.md`, `context/CONTEXT.md` и `context/FRONTEND_API.md`.

Снимок поведения до замены UI лежит в `docs/legacy/`. Пробелы сервера, которые
всплывают при новом интерфейсе, дописывайте в `docs/backend-changes.md`.

## Назначение проекта

Druna помогает пользователям вести личные события, добавлять друзей, создавать
группы и искать общее свободное время. Клиент написан на Flutter и предназначен
для iOS и Android. Интерфейс русскоязычный и основан на локальном экспорте
Figma-прототипа v18 из `context/druna-prototype-v18-source.zip`.

Backend находится в отдельном репозитории DrunaServer:
`https://github.com/TG4-Dev/DrunaServer`. Контракт мобильного API хранится в
`context/FRONTEND_API.md` и является источником истины для endpoint, DTO и
поведения авторизации.

## Текущее состояние

Старый демонстрационный код `one_day`, `one_week` и прежний API-клиент удалены.
Приложение перестроено по функциональным областям и подключено к REST API.

Реализовано:

- splash и восстановление локальной сессии;
- регистрация, автоматический вход после регистрации, вход и выход;
- безопасное хранение access/refresh token через `flutter_secure_storage`;
- Bearer-заголовок, разбор envelope `{data,error}` и русские сетевые ошибки;
- единый refresh для одновременно полученных `401`, ротация пары токенов и
  однократный повтор исходного запроса;
- профиль текущего пользователя и редактирование имени/avatar URL;
- список, создание, редактирование и удаление личных событий;
- вычисление личного свободного времени;
- список друзей, поиск, отправка заявки, входящие/исходящие заявки, принятие,
  отклонение и удаление друга;
- список, создание и детали групп, добавление участника, выход и удаление группы;
- групповые события, общее свободное время и подтверждение времени группы;
- экран уведомлений на основе polling входящих заявок;
- loading, empty, error, refresh, validation и delete-confirmation состояния;
- тёмная визуальная система прототипа: градиенты, карточки, цветовые поля,
  орбитальная композиция главного экрана и нижняя навигация;
- адаптация под Safe Area и Dynamic Island;
- конфигурация API через `--dart-define`/`--dart-define-from-file`;
- unit/widget-тесты API-клиента, моделей, welcome flow и валидации регистрации.

Не реализовано, потому что этого нет в текущем backend-контракте:

- опросы;
- гостевые приглашения;
- серверные push-уведомления и регистрация device token;
- подключение и синхронизация Apple/Google/Outlook Calendar;
- загрузка изображения аватара (API принимает только уже размещённый URL).

UI не должен показывать ложный успех для этих функций. До расширения API нужно
оставлять честное сообщение о недоступности.

## Структура

```text
lib/
  app/             DrunaApp, композиция зависимостей, состояние сессии
  core/api/        Dio-клиент, envelope, refresh и ApiException
  core/config/     APP_ENV и API_BASE_URL
  core/storage/    модель токенов и secure storage
  core/theme/      тема и дизайн-токены
  features/auth/   welcome, sign-in и sign-up
  features/home/   главный экран, навигация и личные события
  features/events/ редактор события
  features/friends/друзья, поиск и заявки
  features/groups/ группы, участники, события и свободное время
  features/notifications/ polling входящих заявок
  features/profile/профиль и выход
  models/          доменные модели и DTO mapping
  repositories/    типизированные операции DrunaServer
  shared/ui/       переиспользуемые визуальные компоненты
test/              unit- и widget-тесты
config/            development и production example build config
context/           исходное ТЗ, API guide и архив прототипа
docs/legacy/       снимок поведения клиента до замены UI
docs/backend-changes.md  журнал недостающих endpoint и изменений DTO
```

Ключевые точки входа:

- `lib/main.dart` — чтение build config и запуск приложения;
- `lib/app/druna_app.dart` — создание API, repository и session controller;
- `lib/app/session_controller.dart` — состояние авторизации;
- `lib/core/api/api_client.dart` — весь HTTP/session lifecycle;
- `lib/repositories/druna_repository.dart` — операции предметной области;
- `lib/models/models.dart` — отображение серверных DTO в модели клиента.

## API и окружения

Не хардкодьте адрес сервера в Dart-коде. Используйте `API_BASE_URL`.

Стандартная development-конфигурация:

```text
config/development.json -> http://localhost:8000
```

Адрес зависит от цели запуска:

| Цель | Пример адреса |
|---|---|
| iOS Simulator, backend на Mac | `http://localhost:22000` |
| Android Emulator, backend на Mac | `http://10.0.2.2:22000` |
| Физический телефон в той же LAN | `http://192.168.0.102:22000` |
| Production | реальный `https://...` endpoint |

Для LAN backend должен слушать `0.0.0.0`, а firewall должен пропускать порт.
Локальный HTTP допустим только для разработки; production обязан использовать
HTTPS. Не коммитьте production secrets или реальные пользовательские токены.

## Запуск

Установить зависимости:

```bash
flutter pub get
```

iOS Simulator со стандартным config:

```bash
flutter run \
  -d 1246EEFE-E718-4DE2-AE96-2DE0DD2EF254 \
  --dart-define-from-file=config/development.json
```

iOS Simulator с Docker backend на порту 22000:

```bash
flutter run \
  -d 1246EEFE-E718-4DE2-AE96-2DE0DD2EF254 \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:22000
```

Физический iPhone в локальной сети:

```bash
flutter run \
  -d <DEVICE_ID> \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://<MAC_LAN_IP>:22000
```

Не запускайте `flutter run` без `-d`, если одновременно доступны macOS и
симуляторы: Flutter предложит выбор, и легко случайно собрать desktop-версию.

## Проверенное окружение

На момент 2026-07-26 установлено и проверено:

- macOS 26.5.2 на Apple Silicon;
- Flutter stable 3.44.8, Dart 3.12.2;
- Xcode 26.6 и CocoaPods 1.17.0;
- iOS Simulator runtime 26.5;
- симулятор `Druna iPhone 17 Pro`, UDID
  `1246EEFE-E718-4DE2-AE96-2DE0DD2EF254`;
- debug-сборка iOS Simulator успешно собрана, установлена и запущена;
- `flutter analyze` проходит без замечаний;
- `flutter test` — 11 тестов проходят.

Android SDK и Chrome в этом окружении не установлены. Android-сборка не была
проверена. Запуск на физическом iPhone и release signing также не проверялись.

## Обязательные проверки перед коммитом

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Если менялись iOS native-файлы, дополнительно:

```bash
flutter build ios \
  --simulator \
  --debug \
  --dart-define-from-file=config/development.json
```

После установки Android SDK нужно добавить Android debug build в регулярную
проверку.

## Правила внесения изменений

- Сохраняйте feature-first структуру и не возвращайте удалённый prototype-код.
- Сетевые вызовы добавляйте в `DrunaRepository`, а общий transport/session код —
  только в `ApiClient`.
- DTO преобразуйте в типизированные модели; не передавайте необработанные Map в UI.
- Токены храните только через `TokenStore`/secure storage.
- Не добавляйте отдельный refresh в feature-код: concurrency уже обрабатывает
  `ApiClient`.
- Не дублируйте цвета и основные размеры; используйте тему и shared widgets.
- Для каждого сетевого экрана сохраняйте loading, empty и error состояния.
- Любое новое поведение API покрывайте unit-тестами; критические UI-сценарии —
  widget-тестами.
- Не редактируйте сгенерированные registrant-файлы вручную.
- Не коммитьте `build/`, `.dart_tool/`, токены, signing certificates и локальный
  `config/production.json`.
- Когда новый UI требует поведения, которого нет в текущем API, допишите пункт
  в `docs/backend-changes.md`: сценарий клиента, предлагаемое изменение контракта
  или статус `уточнить`, зачем существующих вызовов `DrunaRepository` недостаточно.
  Не показывайте ложный успех вместо отсутствующего endpoint.
- Поведение экранов до замены UI не восстанавливайте по памяти: читайте
  `docs/legacy/`.

## Что нужно сделать дальше

Приоритет P0 — до первой тестовой раздачи:

1. Поднять актуальный DrunaServer и провести end-to-end smoke test всех endpoint
   на реальных данных; сверить фактические DTO с `FRONTEND_API.md`.
2. Добавить test/staging `API_BASE_URL` и тестового пользователя без хранения
   пароля в Git.
3. Заменить `com.example.drunaApp` на официальный bundle/application ID.
4. Настроить Apple Development Team, provisioning profile и проверить запуск на
   физическом iPhone.
5. Установить Android SDK, проверить debug build и запуск на Android Emulator и
   физическом устройстве.
6. Проверить адаптивность, клавиатуру, локальный HTTP/ATS и сетевые ошибки на
   нескольких размерах iPhone/Android.

Приоритет P1 — качество продукта:

1. Добавить integration tests для auth, events, friends и groups с mock server.
2. Добавить устойчивое периодическое обновление уведомлений и lifecycle handling;
   сейчас обновление основано на открытии экрана и ручном refresh.
3. Уточнить продуктовую навигацию и состояния по окончательному Figma-файлу;
   текущий источник — локальный prototype export, без живой ссылки на Figma.
4. Добавить accessibility labels, Dynamic Type/text scaling, contrast audit и
   локализацию вместо строк, зашитых в виджеты.
5. Добавить observability: безопасное логирование request ID, crash reporting и
   аналитику без записи токенов/персональных данных.
6. Настроить CI для format, analyze, tests и debug builds обеих платформ.

Приоритет P2 — после расширения backend:

1. Push notifications и управление device token.
2. Calendar integrations Apple/Google/Outlook.
3. Опросы, гостевые приглашения и связанные экраны.
4. Backend upload для аватаров вместо ручного URL.
5. Offline cache и оптимистичные обновления, если это подтвердит продукт.

## Release checklist

- production API работает только через HTTPS;
- bundle/application IDs и display metadata финализированы;
- иконки, splash, privacy descriptions и store assets готовы;
- Apple/Google signing хранится вне репозитория;
- версия/build number обновлены;
- unit, widget, integration и device smoke tests проходят;
- проверены logout, истёкший access token, невалидный refresh token, offline,
  timeout, пустые списки и destructive confirmations;
- удалены debug endpoints и тестовые учётные данные;
- подготовлены privacy policy и сведения App Store/Google Play.
