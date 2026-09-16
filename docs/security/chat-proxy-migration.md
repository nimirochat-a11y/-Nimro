# Chat proxy migration — replacing the direct Supabase connection

## Why

The Flutter app opened a PostgREST connection to Supabase straight from the
handset, authenticating with the publishable key baked into the APK
(`sb_publishable_...` in `lib/common/service/supabase/supabase_service.dart`).

The three tables it addressed — `messages`, `conversations`, `app_users` — had
**no Row Level Security and no revoked `anon` grants**, so anyone who extracted
that key from the bundle could read every message and every user row:

```
GET /rest/v1/messages?select=*        -> 200, 62 rows
GET /rest/v1/conversations?select=*   -> 200, 31 rows
GET /rest/v1/app_users?select=*       -> 200, 18 rows (real emails)
DELETE /rest/v1/conversations?...     -> 204 (write path also open)
```

RLS cannot simply be switched on while the app still talks to Supabase
directly: the app signs in with **Firebase Auth**, so there is no Supabase
session and `auth.uid()` would be NULL — every ownership policy would match
nothing and the chat would break.

## The safe order (chosen)

1. **Move the traffic first.** Route chat through the backend. The backend
   holds the `service_role` key on the server only; `service_role` bypasses RLS
   by definition, so the chat keeps working before, during and after RLS goes on.
2. **Then close the door.** Enable RLS and revoke `anon`/`authenticated` grants.
   Nothing in the app talks to those tables directly any more, so nothing breaks.

The reverse order would have broken the chat.

## Components

### Client (this repo)

| File | Change |
|---|---|
| `lib/common/service/supabase/chat_api_repository.dart` | **new** — same API as `ChatRepository`, but calls `/api/chat/*` on the Nimiro backend |
| `lib/common/controller/firebase_firestore_controller.dart` | rewired — `app_users` access now via the proxy |
| `lib/screen/chat_screen/chat_screen_controller.dart` | `ChatRepository` -> `ChatApiRepository`; `RealtimeChannel` -> `ChatSubscription` |
| `lib/screen/message_screen/message_screen_controller.dart` | same rewiring |
| `lib/screen/dashboard_screen/dashboard_screen_controller.dart` | same rewiring |

`ChatRepository` and `supabase_service.dart` are **left in place on purpose**.
The Supabase client is still used for OAuth sign-in
(`signInWithOAuth` in `auth_screen_controller.dart`) and for `ping`/`signOut`
in settings. That is a different mechanism and never touches the three
RLS-protected tables, so it keeps working after lockdown.

### Kill switch

`ChatApiRepository.useApi = false` restores the previous direct-Supabase path,
so a bad release can be reverted without a code change.

### Backend (deployed separately)

| File | Purpose |
|---|---|
| `config/supabase.php` | reads `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` from `.env` |
| `app/Services/SupabaseClient.php` | minimal PostgREST client; key never logged or returned |
| `app/Http/Controllers/ChatController.php` | the 10 `/api/chat/*` endpoints |
| `routes/api.php` | chat routes added inside the existing `checkHeader` group |

Every endpoint (except the conversation/message lists and the app_user upsert)
sits behind the `authorizeUser` middleware. The acting user id is taken from
the token resolved by that middleware — **never** from the request body, so a
caller cannot read or write another user's rows.

`.env` additions (server only — never commit values):

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_KEY=<service_role key>
SUPABASE_CHAT_ENABLED=true
```

## Deployment order

1. Add the two `SUPABASE_*` values to the server `.env`.
2. Deploy the backend files (`deploy_chat_proxy.sh` — backs up, syntax-checks
every file, rolls back on failure).
3. Confirm the app works end to end: login, open chat, send, receive,
conversation list.
4. Only then run `enable_rls.sql` in the Supabase SQL Editor.

Step 4 is deliberately last: at that point no client path depends on the
exposed key any more.

## Realtime

Supabase Realtime (`RealtimeChannel` on `postgres_changes`) is not available to
the app once RLS is on and the publishable key is gone, so change delivery is
polled through the backend (3–5s). Polling was chosen deliberately for the
first step: no new server component, survives RLS, and can be swapped for
websockets later without touching any caller — the call sites only ever see
`.subscribeToX(...)` / `.unsubscribe(...)`.
