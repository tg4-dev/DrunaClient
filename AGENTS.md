# DrunaClient — руководство для разработчиков и AI-агентов

Этот файл описывает текущее состояние Flutter-клиента Druna, правила работы с
репозиторием, локальный запуск и оставшиеся задачи. Перед изменениями также
прочитайте `README.md`, `context/CONTEXT.md`, `context/FRONTEND_API.md` и
`docs/design-system.md`.

Снимок поведения до замены UI лежит в `docs/legacy/`. Пробелы сервера, которые
всплывают при новом интерфейсе, дописывайте в `docs/backend-changes.md`.

## Назначение проекта

Druna помогает пользователям вести личные события, добавлять друзей, создавать
группы и искать общее свободное время. Клиент написан на Flutter и предназначен
для iOS и Android. Интерфейс русскоязычный. Источник дизайна — Figma автора,
которая приходит скриншотами; всё, что из неё уже известно, записано в
`docs/design-system.md`. Прототип v18 (`context/druna-prototype-v18-source.zip`)
источником дизайна больше не является.

Backend находится в отдельном репозитории DrunaServer:
`https://github.com/TG4-Dev/DrunaServer`. Контракт мобильного API хранится в
`context/FRONTEND_API.md` и является источником истины для endpoint, DTO и
поведения авторизации.

## Текущее состояние

Идёт замена UI. Летом 2026 был сделан клиент по прототипу v18; осенью
интерфейс переписывается по Figma. Состояние на 2026-10-20:

- **Новый UI.** После входа открывается `HomePager`
  (`lib/app/home_pager.dart`): страницы на одной горизонтальной плоскости —
  «Друзья» слева от календаря, «Настройки» справа; переход свайпом, в
  настройки ещё и шестерёнкой на месяце. Календарь (`lib/features/calendar/`)
  пока работает на демо-событиях в памяти. Страница «Друзья»
  (`lib/features/friends/`) ходит в сервер через `FriendsSource` или работает
  на `DemoFriendsSource`: 2 друга и 1 входящая заявка.
- **Настройки** (`lib/features/settings/`, `lib/app/app_settings.dart`):
  аккаунт и выход, адрес сервера, ping, проверка refresh токена, демо-друзья,
  имитация «нет сети», замедление анимаций. Переключатели хранятся в
  `shared_preferences`. Вне production демо-друзья включены по умолчанию;
  в production демо-переключателей нет.
- **Аватары.** У людей нет фото: везде `PersonAvatar`
  (`lib/shared/ui/person_avatar.dart`) — цвет из палитры 16 цветов и первая
  буква имени.
- **Старый UI.** Экраны прототипа v18 (home, friends, groups, profile,
  notifications, редактор событий) удалены. Остались только вход и сплэш
  (`features/auth/`, `core/theme/druna_theme.dart`,
  `shared/ui/druna_widgets.dart`), чтобы приложение могло войти в сервер. Их
  заменят по Figma. Как работали удалённые экраны — `docs/legacy/`.
- **Слой данных** (`ApiClient`, `DrunaRepository`, модели, `SessionController`,
  `TokenStore`) сохранён целиком: группы, события и профиль снова подключатся к
  нему, когда для них появится новый UI.

Слой данных и вход умеют:

- splash и восстановление локальной сессии;
- регистрация, автоматический вход после регистрации, вход и выход;
- безопасное хранение access/refresh token через `flutter_secure_storage`;
- Bearer-заголовок, разбор envelope `{data,error}` и русские сетевые ошибки;
- единый refresh для одновременно полученных `401`, ротация пары токенов и
  однократный повтор исходного запроса;
- профиль, личные и групповые события, свободное время, группы — методы
  `DrunaRepository` без UI;
- друзья: список, поиск, заявка, входящие/исходящие, принять, отклонить,
  удалить — с UI на странице «Друзья»;
- конфигурация API через `--dart-define`/`--dart-define-from-file`;
- unit/widget-тесты API-клиента, моделей, входа, календаря, аватаров,
  страницы друзей и листания страниц.

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
  app/             DrunaApp, HomePager (плоскость страниц), состояние сессии
  core/api/        Dio-клиент, envelope, refresh и ApiException
  core/config/     APP_ENV, API_BASE_URL и DEMO_DATA
  core/storage/    модель токенов и secure storage
  core/theme/      старая тема; нужна только входу, уйдёт с ним
  features/auth/   старые welcome, sign-in и sign-up (до перерисовки)
  features/calendar/ новый календарь: месяц, день, лист события (демо-данные)
  features/friends/  новая страница «Друзья», FriendsSource и демо-источник
  features/settings/ страница «Настройки» с параметрами для тестирования
  models/          доменные модели и DTO mapping
  repositories/    типизированные операции DrunaServer
  shared/ui/       PersonAvatar, блоки страниц, нативные диалоги, старые
                   виджеты входа
test/              unit- и widget-тесты
config/            development и production example build config
context/           исходное ТЗ, API guide и архив прототипа v18
docs/design-system.md    дизайн-система и журнал дизайн-решений
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

Стандартная development-конфигурация `config/development.json` задаёт
`API_BASE_URL` и `DEMO_DATA=true`. Демо-данные (сейчас «Друзья») включаются
и выключаются на странице «Настройки»; `DEMO_DATA` и окружение задают только
значение по умолчанию: вне production демо включено. Вход по-прежнему идёт
через сервер. В production демо-данных нет.

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
- `flutter test` проходит (на 2026-10-20 — 103 теста).

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
- Визуальные значения берите из `docs/design-system.md` и кода нового
  календаря, не из `DrunaColors`/`druna_widgets.dart` и не из прототипа v18.
- Каждое дизайн-решение, которое описывает автор (в чате, скриншотом или
  словами), записывайте в `docs/design-system.md`: в нужный раздел и в журнал
  решений (§13). Значения, не сверенные с Figma, помечайте 🟡.
- Людей везде показывайте через `PersonAvatar`: цвет из палитры и первая
  буква имени, фото нет.
- Новые главные разделы добавляйте страницами в `HomePager`, а не через
  `Navigator.push` с главной.
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
3. Перерисовать по Figma вход и сплэш, затем удалить `druna_theme.dart` и
   `druna_widgets.dart`; вернуть группы, профиль и события на сервере в новом
   UI (`docs/design-system.md`, §10.1).
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
