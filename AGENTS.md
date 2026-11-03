# DrunaClient — правила для разработчиков и AI-агентов

Druna помогает вести личные события, добавлять друзей и искать общее свободное
время. Клиент — Flutter, iOS и Android, интерфейс на русском. Backend —
отдельный репозиторий DrunaServer (`https://github.com/TG4-Dev/DrunaServer`).

Здесь только правила. Что где лежит и как выглядит — в документах, читайте тот,
что относится к задаче:

| Документ | О чём |
|---|---|
| `docs/design-system.md` | текущие визуальные значения и поведение экранов |
| `docs/design-decisions.md` | журнал решений автора по дизайну |
| `docs/avatar.md` | цвета и шрифты аватара |
| `context/FRONTEND_API.md` | контракт API — источник истины для endpoint и DTO |
| `docs/backend-changes.md` | чего не хватает в API для нового UI |
| `docs/legacy/` | как работали экраны до замены UI; `brief.md` — исходное ТЗ (история) |
| `docs/roadmap.md` | что сделать дальше и release checklist |

## Дизайн-решения принимает только автор

Источник дизайна — автор: Figma скриншотами, эскизы и слова в чате. Они
окончательны. Агент дизайн не придумывает.

- **Любое визуальное значение, которого нет в `docs/design-system.md` и которое
  автор не назвал в текущем разговоре, — спросить автора.** Цвет, размер,
  отступ, радиус, шрифт, прозрачность, длительность, кривая, анимация, эффект.
  Не выбирать «разумное» значение и не копировать молча соседнее.
- **Не добавлять украшений, о которых не просили:** анимации, свечение, тени,
  blur, градиенты, переходы, лесенки, пружины с перелётом, «поп»-масштабы.
  Движение — минимально нужное и быстрое.
- **Исправление бага и рефакторинг не меняют вид.** Если без этого нельзя —
  сначала спросить.
- **Неоднозначный запрос** — предложить 2–3 варианта и спросить, а не
  реализовать один из них.
- **В `docs/design-system.md` и журнал пишется только то, что сказал автор**, с
  датой. Собственные технические решения агента (как реализовано) в журнал
  решений не идут.
- Визуальные значения берите из `docs/design-system.md` и кода нового UI, не из
  `docs/legacy/` и не из прототипа v18.
- Если код расходится с `docs/design-system.md` — не «чинить» молча ни то, ни
  другое: сказать автору.

## Что работает на сервере, а что на демо

- Сервер: вход по нику, регистрация, профиль (имя), друзья и заявки.
- Демо, потому что сервер этого не умеет: календарь (события в памяти),
  занятость друзей, приглашения, код из письма, проверка ника, вход по почте.
  **В production войти нельзя**, пока сервер не получит контракт из
  `docs/backend-changes.md`.
- Без UI, только в `DrunaRepository`: личные и групповые события, свободное
  время, группы.
- Нет совсем: опросы, гостевые приглашения, push, синхронизация внешних
  календарей, загрузка аватара. UI не показывает ложный успех — честно пишет
  «не поддерживается».

## Структура

```text
lib/
  app/             DrunaApp, HomePager (плоскость страниц), сессия, настройки
  core/api/        Dio-клиент, envelope, refresh и ApiException
  core/config/     APP_ENV, API_BASE_URL, DEMO_DATA, OFFLINE
  core/storage/    модель токенов и secure storage
  features/onboarding/ вход и регистрация: шаги, контроллер, источники
  features/calendar/   календарь: месяц и день
  features/event_page/ форма события
  features/friends/    «Друзья», friend bar, занятость друзей
  features/invites/    приглашения
  features/settings/   профиль и настройки
  models/          доменные модели и DTO mapping
  repositories/    типизированные операции DrunaServer
  shared/ui/       общие виджеты: PersonAvatar, PillButton, ActionPill,
                   PillField, showToast, имя капсом, бренд, confirmAction
test/              unit- и widget-тесты
assets/            логотип, стрелка, шрифты (OFL)
shaders/           фон формы события, полосы недели
config/            development, offline (без сервера), production example
scripts/           dev_server.sh: DrunaServer в Docker для телефона в LAN
```

Точки входа: `lib/main.dart` (build config), `lib/app/druna_app.dart` (API,
repository, session), `lib/app/session_controller.dart`,
`lib/core/api/api_client.dart`, `lib/repositories/druna_repository.dart`,
`lib/models/models.dart`.

## Правила кода

- Feature-first структура; удалённый prototype-код не возвращать.
- Людей показывать через `PersonAvatar`: цвет из палитры и первая буква, фото
  нет. Имена — капсом и жирно (`NameText`, `nameStyle`).
- Любая кнопка — `PillButton`; да/нет и отмена/подтверждение — `ActionPill`.
  Ввод — `PillField`, без нативных диалогов ввода. Уведомление — `showToast`,
  без Snackbar.
- Новые главные разделы — страницами в `HomePager`, не `Navigator.push` с
  главной.
- Сетевые вызовы — в `DrunaRepository`, transport/session — только в
  `ApiClient`. Отдельный refresh в feature-коде не делать.
- DTO преобразовывать в модели; сырые Map в UI не передавать.
- Токены — только через `TokenStore`/secure storage.
- Цвета и размеры не дублировать — брать из существующих стилей и shared
  widgets.
- У сетевого экрана есть loading, empty и error.
- Новое поведение API — unit-тесты; критические UI-сценарии — widget-тесты.
- Не хватает API — пункт в `docs/backend-changes.md` (сценарий, предлагаемый
  контракт или `уточнить`), а в UI честное «не поддерживается».
- Поведение старых экранов не восстанавливать по памяти — читать
  `docs/legacy/`.
- Не редактировать сгенерированные registrant-файлы. Не коммитить `build/`,
  `.dart_tool/`, токены, signing и `config/production.json`.

## Процесс

- Один заход — одна тема. Коммиты делает автор; в конце предложите, как
  разбить изменения на коммиты.
- Не дописывайте в этот файл хронику изменений: состояние фич — в
  `docs/design-system.md`, планы — в `docs/roadmap.md`.

Перед сдачей:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Если менялись iOS native-файлы — ещё
`flutter build ios --simulator --debug --dart-define-from-file=config/development.json`.

## API и окружения

Адрес сервера не хардкодить — `API_BASE_URL`. Production — только HTTPS.

| Цель | Адрес |
|---|---|
| iOS Simulator, backend на Mac | `http://localhost:22000` |
| Android Emulator, backend на Mac | `http://10.0.2.2:22000` |
| Телефон в той же LAN | `http://<IP Mac>:22000` (`ipconfig getifaddr en0`) |
| Production | `https://...` |

- `config/development.json` — `API_BASE_URL` и демо. Вне production демо
  включено по умолчанию и переключается в настройках; в production демо нет.
- `scripts/dev_server.sh` поднимает DrunaServer из `../DrunaServer` в Docker,
  ждёт `/ping/` и прописывает LAN-адрес Mac в `config/development.json`.
  Остановить — `scripts/dev_server.sh stop`.
- `config/offline.json` (`OFFLINE=true`) — без сервера: онбординг на
  устройстве (код `123456`, аккаунт локально в `OfflineAccounts`), остальное на
  демо. В production флаг игнорируется.

## Запуск

```bash
flutter pub get
flutter run -d <DEVICE_ID> --dart-define-from-file=config/development.json
```

Симулятор `Druna iPhone 17 Pro`: `1246EEFE-E718-4DE2-AE96-2DE0DD2EF254`.
Не запускайте `flutter run` без `-d`: Flutter может собрать desktop-версию.
Android-сборка и физический iPhone пока не проверялись.
