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
интерфейс переписывается по Figma. Состояние на 2026-11-02:

- **Новый UI.** После входа открывается `HomePager`
  (`lib/app/home_pager.dart`): одна горизонтальная плоскость
  «Друзья ← Мой календарь | Календарь друзей → Профиль», старт на календаре
  друзей. Между двумя положениями календаря сетка стоит на месте, а свайп
  меняет режим: чьи события в полном виде, а чьи — полосой у линии недели. Внизу friend
  bar (`lib/features/friends/friend_bar.dart`): выбор друзей, их занятость
  в календаре их цветом. Описание — `docs/design-system.md` §9.4, §10.1.
  Календарь (`lib/features/calendar/`) пока работает на демо-событиях в
  памяти; занятость друзей — только демо (`DemoFriendSchedule`), сервер её не
  отдаёт. Страница «Друзья»
  (`lib/features/friends/`) ходит в сервер через `FriendsSource` или работает
  на `DemoFriendsSource`: 12 друзей и 1 входящая заявка.
- **Приглашения** (`lib/features/invites/`, `docs/design-system.md` §9.8):
  в режиме друзей удержание дня или рисование в дне при выбранных друзьях
  создаёт приглашение. Визуальный язык — градиент цветов участников.
  Ответы — Да / Нет / ещё не ответил; список есть в профиле. У сервера приглашений нет: работают на `DemoInvitesSource`
  вместе с демо-друзьями, иначе `ServerInvitesSource` честно отвечает
  «не поддерживается». Push нет. Контракт — `docs/backend-changes.md`.
- **Форма события** (`lib/features/event_page/`, `docs/design-system.md`
  §9.1): одна форма для моих событий, нового приглашения и общего — лист
  снизу с просмотром и правкой, заголовок Unbounded, своё редактирование дат и
  времени, блок «Отметить присутствие», анимированный градиент на шейдере
  (`shaders/event_gradient.frag`). Прежние `EventDurationSheet` и
  `InvitePage` удалены.
- **Профиль и настройки** (`lib/features/settings/`,
  `lib/app/app_settings.dart`): сверху профиль (аватар в моём цвете, имя с
  правкой через `PATCH /users/me`, @username, email), блок «События» с
  приглашениями (полки карточек), «Мой цвет»; ниже адрес сервера, ping, проверка refresh
  токена, демо-данные, замедление анимаций и «Выйти». Переключатели хранятся
  в `shared_preferences`. Вне production демо-друзья включены по умолчанию;
  в production демо-переключателей нет.
- **Аватары.** У людей нет фото. Везде `PersonAvatar`
  (`lib/shared/ui/person_avatar.dart`): круг с градиентом 45° цвета из
  палитры 8 цветов и первая буква имени выбранным шрифтом (6 шрифтов,
  оптическая центровка). Свой цвет и шрифт выбираются на шаге «Профиль» и в
  настройках (`lib/shared/ui/profile_pickers.dart`) и хранятся на
  устройстве. **Как менять цвета и шрифты — `docs/avatar.md`**; подгонка
  шрифтов — экран «Подгонка аватаров» в демо-блоке настроек.
- **Онбординг** (`lib/features/onboarding/`, `docs/design-system.md` §9.9),
  с 2026-11-02 вместо старого входа:
  - welcome (Apple и Google пока плейсхолдеры) → почта;
  - новая почта → код → пароль → ник → имя → профиль (аватар, шрифт,
    цвет; фон перекрашивается в выбранный) → «Всё готово»;
    зарегистрированная почта → пароль;
  - на каждом шаге ← →, данные сохраняются; фон — `EventGradient` в
    чёрном и `Brand.accent`.

  Сервер умеет только `sign-up`/`sign-in` по нику. Поэтому код, проверка
  ника и вход по почте работают на `DemoAuthFlowSource`, финальная
  регистрация — настоящая. `ServerAuthFlowSource` честно отвечает «не
  поддерживается»: **в production войти нельзя, пока сервер не получит
  контракт** из `docs/backend-changes.md`. Сессия пускает в приложение
  через `SessionController.adopt()`, когда доиграл последний экран.
  В настройках «Пройти онбординг» проигрывает весь поток без сервера
  (`RehearsalAuthFlowSource`, `showOnboardingRehearsal`), а «Пройти вход» —
  только вход: любая почта ведёт к паролю, `wrongpass` — ошибка.
  Пароль из автозаполнения отправляется сам через 0.4 с, после входа —
  «Всё готово»; «забыл пароль?»
  пока честно не поддерживается.
- **Имена людей — капсом и жирно** везде (`shownName`, `nameStyle`,
  `NameText`, `lib/shared/ui/person_name.dart`); сервер хранит как введено.
- **Без нативных диалогов ввода.** Имя меняется полем-капсулой (`PillField`,
  `lib/shared/ui/pill_field.dart`), `askText` удалён.
- **Кнопка** светится при нажатии (`PillButton`, §9.5).
- **Уведомления** — одна плашка сверху в стиле кнопки
  (`showToast`, `lib/shared/ui/top_toast.dart`, §9.10), Snackbar не
  используются.
- **Старый UI удалён** 2026-11-02: экраны прототипа v18, старый вход,
  `druna_theme.dart`, `druna_widgets.dart` и лого «ü». Значения старой темы,
  на которые ещё опираются «Друзья» и профиль, временно в
  `lib/app/app_theme.dart`. Как работали старые экраны — `docs/legacy/`.
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
- профиль: чтение и правка имени — с UI в профиле;
- личные и групповые события, свободное время, группы — методы
  `DrunaRepository` без UI (покрытие API — `docs/backend-changes.md`);
- друзья: список, поиск, заявка, входящие/исходящие, принять, отклонить,
  удалить — с UI на странице «Друзья»;
- конфигурация API через `--dart-define`/`--dart-define-from-file`;
- unit/widget-тесты API-клиента, моделей, онбординга, календаря, аватаров,
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
  app/             DrunaApp, HomePager (плоскость страниц), состояние сессии,
                   временная тема (app_theme.dart)
  core/api/        Dio-клиент, envelope, refresh и ApiException
  core/config/     APP_ENV, API_BASE_URL и DEMO_DATA
  core/storage/    модель токенов и secure storage
  features/onboarding/ вход и регистрация: шаги, контроллер, правила полей,
                   источники (демо и сервер), поле, ячейки кода, Apple/Google
  features/calendar/ новый календарь: месяц и день (демо-данные)
  features/event_page/ форма события: просмотр и правка, заголовок,
                     время, повтор, присутствие, анимированный фон
  features/friends/  страница «Друзья», FriendsSource и демо-источник,
                     friend bar, выбор друзей, их занятость (демо)
  features/invites/  приглашения: модель, источники (демо и сервер), store,
                     страница приглашения, блок «События» профиля
  features/settings/ профиль и настройки с параметрами для тестирования
  models/          доменные модели и DTO mapping
  repositories/    типизированные операции DrunaServer
  shared/ui/       PersonAvatar и его стиль (цвета, шрифты, центровка), пикеры
                   профиля, PillField, имя капсом и жирно, PillButton и
                   ActionPill, уведомление, OKLab, бренд
                   (лого, стрелка, цвет), блоки страниц, нативные диалоги
test/              unit- и widget-тесты
assets/branding/   логотип и стрелка онбординга (SVG, flutter_svg)
assets/fonts/      Onest и Unbounded; avatar/ — шрифты буквы аватара (OFL) (вариативные, OFL; Unbounded — только заголовок формы события)
shaders/           фон формы события (event_gradient.frag)
config/            development, offline (без сервера) и production example build config
scripts/           dev_server.sh: DrunaServer в Docker для телефона в LAN
context/           исходное ТЗ, API guide и архив прототипа v18
docs/design-system.md    дизайн-система и журнал дизайн-решений
docs/avatar.md     цвета и шрифты аватара: как менять и подгонять
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
| Физический телефон в той же LAN | `http://192.168.0.102:22000` (IP Mac меняется по DHCP: `ipconfig getifaddr en0`) |
| Production | реальный `https://...` endpoint |

Для LAN backend должен слушать `0.0.0.0`, а firewall должен пропускать порт.

Сервер для телефона в той же Wi-Fi поднимает `scripts/dev_server.sh`:

- запускает Docker Desktop;
- собирает и поднимает DrunaServer из `../DrunaServer` через
  `docker compose up -d --build`;
- ждёт `/ping/` и проверяет, что сервер отвечает по LAN-IP Mac;
- прописывает этот адрес в `config/development.json` — IP выдаёт роутер,
  он меняется.

**Без сервера вообще** — `config/offline.json` (`OFFLINE=true`):

```bash
flutter run -d <DEVICE_ID> --dart-define-from-file=config/offline.json
```

- онбординг целиком на устройстве: код `123456`, аккаунт и сессия хранятся
  локально (`OfflineAccounts`, `lib/app/offline_accounts.dart`), вход в
  созданный аккаунт — с любым паролем;
- профиль и правка имени — локальные;
- друзья, их занятость, приглашения и календарь — на демо-данных;
- ping и проверка refresh в настройках честно не проходят.

В production флаг игнорируется (`AppConfig.offline`).

Остановить — `scripts/dev_server.sh stop`. Docker Desktop должен быть
разрешён во входящих соединениях фаервола macOS.
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
- `flutter test`: на 2026-11-03 — 275 тестов, 274 проходят. Падает
  `calendar_month_test.dart` «pinned top weeks run on under the top» (зависит
  от текущей даты, падает и на коммите `55179fa`). В тестах
  progressive blur выключен (`test/flutter_test_config.dart`, `EdgeBlur`).

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
  решений (§13). Помечать значения 🟡 и сверять их с Figma больше не нужно
  (решение автора 2026-11-03): эскизы и слова автора окончательны.
- Людей везде показывайте через `PersonAvatar`: цвет из палитры и первая
  буква имени, фото нет.
- Любая кнопка — `PillButton` (`lib/shared/ui/pill_button.dart`): иконка,
  текст или оба, без blur и нативных view (`docs/design-system.md` §9.5).
  Действие да/нет, отмена/подтверждение — `ActionPill`
  (`lib/shared/ui/action_pill.dart`), large или compact.
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
7. Серверный вход по почте: endpoint из `docs/backend-changes.md` («Вход и
   регистрация по почте») и `ServerAuthFlowSource` на них. До этого в
   production войти нельзя.
8. Associated Domains (`webcredentials:`) и `apple-app-site-association`,
   Android `assetlinks.json` — иначе система не предлагает сохранить пароль.

Приоритет P1 — качество продукта:

1. Добавить integration tests для auth, events, friends и groups с mock server.
2. Добавить устойчивое периодическое обновление уведомлений и lifecycle handling;
   сейчас обновление основано на открытии экрана и ручном refresh.
3. Перевести «Друзья» и профиль на свои стили и удалить `app_theme.dart`;
   вернуть группы, профиль и события на сервере в новом UI
   (`docs/design-system.md`, §10.1). Подключить Sign in with Apple и Google
   (§9.9, правила провайдеров).
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
