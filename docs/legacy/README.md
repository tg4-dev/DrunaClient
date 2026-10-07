# Архив текущего клиента

Снимок поведения Flutter-клиента Druna на **6 октября 2026**, до замены UI.
Исходники экранов в `lib/features/` на момент снимка остаются в репозитории.
Этот каталог нужен, чтобы после переписывания интерфейса можно было прочитать,
как работала каждая функция: какие запросы уходили, какие состояния показывались
и что клиент намеренно не имитировал.

Контракт сервера по-прежнему в [`context/FRONTEND_API.md`](../../context/FRONTEND_API.md).
Здесь зафиксировано, как его вызывает именно этот клиент, включая расхождения
имён полей.

## Оглавление

- [Сервер и сессия](server.md) — base URL, envelope, токены, refresh, все вызовы репозитория.
- [Вход и регистрация](auth.md) — splash, welcome, sign-in, sign-up.
- [Главная и события](events.md) — расписание, редактор, свободное время.
- [Друзья и уведомления](friends.md) — поиск, заявки, polling входящих.
- [Группы](groups.md) — участники, групповые события, общее время, confirm.
- [Профиль](profile.md) — имя, URL аватара, выход, честные заглушки.

Журнал того, чего не хватает на сервере: [`docs/backend-changes.md`](../backend-changes.md).

## Источники снимка

| Область | Файл |
|---|---|
| Композиция | `lib/main.dart`, `lib/app/druna_app.dart` |
| Сессия | `lib/app/session_controller.dart` |
| HTTP | `lib/core/api/api_client.dart`, `lib/core/api/api_exception.dart` |
| Токены | `lib/core/storage/token_store.dart` |
| Конфиг | `lib/core/config/app_config.dart`, `config/development.json` |
| Операции | `lib/repositories/druna_repository.dart` |
| Модели | `lib/models/models.dart` |
| Экраны | `lib/features/**` |

Слой данных (`ApiClient`, `DrunaRepository`, модели, `SessionController`) отделён
от экранов. При новом UI его имеет смысл сохранить и вызывать те же методы,
пока контракт не изменится.

## Навигация приложения

`MaterialApp.home` зависит от `SessionState`:

1. `restoring` — splash с маркой и индикатором, пока читается secure storage.
2. `signedOut` — `AuthScreen`.
3. `signedIn` — `HomeScreen`. Отдельного роутера нет: остальные экраны открываются через `Navigator.push` и `MaterialPageRoute`.

С главной:

- кнопка дня — личное свободное время;
- «+» — создание личного события;
- колокольчик — уведомления, после возврата главная перезагружается;
- шестерёнка — профиль;
- секция «Друзья» — `FriendsScreen`, после возврата перезагрузка;
- секция «Группы» и плитка группы — список групп или сразу `GroupDetailScreen`.

Масштаб текста зажат в диапазоне 0.9–1.35. Локаль дат — `ru_RU`.
