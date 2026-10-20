# Сервер и сессия

Клиент ходит в DrunaServer напрямую по JSON. Cookies и WebView нет.
Адрес не зашит в код фич: его задаёт `API_BASE_URL`.

## Конфигурация

`AppConfig.fromEnvironment()` читает `--dart-define` / `--dart-define-from-file`:

| Ключ | Значение по умолчанию в коде | `config/development.json` на снимке |
|---|---|---|
| `API_BASE_URL` | `http://localhost:22000` | `http://localhost:22000` |
| `APP_ENV` | `development` | `development` |

Хвостовой `/` у base URL срезается. `isProduction` истинно только при `APP_ENV=production`.
Локальный HTTP допустим для разработки; production обязан быть HTTPS.

Ориентиры адреса:

| Цель | Пример |
|---|---|
| iOS Simulator, backend на Mac | `http://localhost:22000` |
| Android Emulator | `http://10.0.2.2:22000` |
| Телефон в той же LAN | `http://<LAN-IP>:22000` |

Таймауты Dio: connect 12 с, send и receive по 18 с. `validateStatus` принимает любой HTTP-код, чтобы разобрать envelope и до 401 дойти до refresh.

## Envelope

Успех: `{ "data": ... }`. Клиент отдаёт в `decode` только `data`.

Ошибка: `{ "error": { "message": "..." } }` становится `ApiException` с текстом `message` и `statusCode`. Если тела-карты нет или в ней нет `error`, а статус ≥ 400, текст — `Сервер вернул ошибку <код>`. Нечитаемое тело — `Не удалось прочитать ответ сервера`.

Сетевые сбои (`ApiException.isNetwork`):

- таймаут connect/send/receive — «Сервер не ответил вовремя. Попробуй ещё раз.»;
- остальной `DioException` — «Нет соединения с сервером.»

`ApiException.toString()` возвращает только `message`, его и показывает UI. `isUnauthorized` — это `statusCode == 401`.

## Токены

Пара: `accessToken` и `refreshToken`. Ключи secure storage: `druna_access_token`, `druna_refresh_token` (`flutter_secure_storage`: Keychain на iOS, Keystore-backed storage на Android). Пара считается живой, только если записаны оба ключа.

`MemoryTokenStore` используется в тестах, в приложении — `SecureTokenStore`.

Публичные вызовы (`publicRequest`) идут без `Authorization`. Защищённые (`request`) ставят `Authorization: Bearer <accessToken>`.

## Жизненный цикл сессии

`SessionState`: `restoring`, `signedOut`, `signedIn`.

1. Старт: `restore()` читает токены. Нет пары — сразу `signedOut`. Есть пара — сразу `signedIn`, затем `GET /api/v1/users/me`. Ошибка профиля на этом шаге глотается: главная сама показывает retry/offline. Неудачный refresh внутри этого GET уже очищает storage; следующий защищённый запрос получит 401.
2. Вход: `POST /auth/sign-in`, сохранить пару, загрузить профиль, `signedIn`.
3. Регистрация: `POST /auth/sign-up` (ответ не разбирается), затем тот же вход с username и паролем.
4. Выход: удалить пару из памяти и storage, обнулить профиль, `signedIn` → `signedOut`. Серверный revoke не вызывается.

## Refresh

На 401 защищённого запроса:

1. Если другой запрос уже успел сменить access token, повтор идёт с новым токеном без второго refresh.
2. Иначе один общий `POST /auth/renew-token` с телом `{ "refreshToken": "..." }`. Параллельные 401 ждут тот же `Future`.
3. Успех: новая пара пишется в storage, исходный запрос повторяется один раз.
4. Нет refresh token или любая ошибка renew: storage очищается, повтор не делается, исходный 401 разбирается как обычная ошибка.

Главная при `isUnauthorized` вызывает `logout()`. Остальные экраны показывают текст ошибки и сами сессию не сбрасывают.

## Модели и терпимость к именам

| Модель | Поля | Замечания разбора |
|---|---|---|
| `UserProfile` | `id`, `name`, `username`, `email`, `avatarUrl?` | аватар: `avatarURL` или `avatarUrl` |
| `DrunaEvent` | `id`, `userId?`, `groupId?`, `title`, `startTime`, `endTime`, `type` | id: `eventID`, иначе `eventId`, иначе `id`. Времена парсятся и переводятся в local. Пустой title → «Без названия», пустой type → `personal` |
| `FriendInfo` | `id`, `name`, `username` | |
| `GroupSummary` | `id`, `name`, `ownerId?`, `members` | id: `groupID` / `groupId` / `id`. owner: `ownerID` / `ownerId`. Участники — список объектов `FriendInfo`, иначе пустой список. Пустое имя → «Группа» |
| `FreeSlot` | `start`, `end` | local |
| `TokenPair` | `accessToken`, `refreshToken` | оба обязательные строки |

Списки из envelope берутся через `mapList`: не-список даёт пустой список, элементы не-Map отбрасываются.

Запрос события (`toRequest`): `title`, `startTime` и `endTime` в UTC ISO-8601, `type`.

## Вызовы `DrunaRepository`

Все пути относительно base URL. Защищённые, кроме двух auth.

| Метод репозитория | HTTP | Путь | Тело или query | Что возвращает |
|---|---|---|---|---|
| `signIn` | POST | `/auth/sign-in` | `{username, password}`, username trim | пара токенов, сразу в storage |
| `signUp` | POST | `/auth/sign-up` | `{name, username, email, password}`, строки trim кроме пароля | пусто, затем `signIn` |
| `getProfile` | GET | `/api/v1/users/me` | — | `UserProfile` |
| `updateProfile` | PATCH | `/api/v1/users/me` | только переданные `name` и/или `avatarURL` | затем повторный GET профиля |
| `listEvents` | GET | `/api/v1/events/` или `/api/v1/groups/:id/events` | — | `data.events` |
| `createEvent` | POST | те же пути | `toRequest()` | `eventId` или `eventID` как int |
| `updateEvent` | PATCH | `.../events/:eventId` | `toRequest()` | пусто |
| `deleteEvent` | DELETE | `.../events/:id` | — | пусто |
| `freeTime` | POST | `/api/v1/events/free-time` или `/api/v1/groups/:id/free-time` | `{date: "YYYY-MM-DD"}` из local ISO, первые 10 символов | `data.freeSlots` |
| `listFriends` | GET | `/api/v1/friends/list` | — | ключ `friends`, запасные `friends`/`users` |
| `incomingRequests` | GET | `/api/v1/friends/requests/incoming` | — | ключ `requests` |
| `outgoingRequests` | GET | `/api/v1/friends/requests/outgoing` | — | ключ `requests`. Метод есть, ни один экран его не вызывает |
| `searchFriends` | GET | `/api/v1/friends/search` | query `username` | ключ `users` |
| `sendFriendRequest` | POST | `/api/v1/friends/request` | `{username}` | пусто |
| `acceptFriend` | POST | `/api/v1/friends/accept` | `{username}` | пусто |
| `rejectFriend` | POST | `/api/v1/friends/reject` | `{username}` | пусто |
| `deleteFriend` | DELETE | `/api/v1/friends/` | `{username}` | пусто |
| `listGroups` | GET | `/api/v1/groups/list` | — | `data.groups` |
| `getGroup` | GET | `/api/v1/groups/:id` | — | объект группы целиком как `data` |
| `createGroup` | POST | `/api/v1/groups/create` | `{name}` trim | `groupId` или `groupID` |
| `addGroupMember` | POST | `/api/v1/groups/:id/members` | `{username}` | пусто |
| `confirmGroupTime` | POST | `/api/v1/groups/:id/confirm` | `{confirmedTime}` UTC ISO | пусто |
| `leaveGroup` | POST | `/api/v1/groups/:id/leave` | без тела | пусто |
| `deleteGroup` | DELETE | `/api/v1/groups/:id` | — | пусто |

`_friendList` если ожидаемого ключа нет, пробует `friends`, затем `users`, затем пустой список.
