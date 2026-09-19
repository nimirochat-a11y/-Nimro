<?php

/*
|--------------------------------------------------------------------------
| Supabase (PostgREST) connection
|--------------------------------------------------------------------------
|
| The Nimiro mobile app talks to Supabase DIRECTLY today, with the public
| publishable key shipped inside the app bundle. That key can read and write
| every message, conversation and app_user row of every user, because the
| tables have no Row Level Security.
|
| The safe fix is to stop the client from talking to Supabase at all and
| route chat traffic through this backend instead. The backend then uses the
| Supabase service_role key, which NEVER leaves the server.
|
| Credentials MUST come from .env. Never hardcode them here.
|
|   SUPABASE_URL          = https://<project-ref>.supabase.co
|   SUPABASE_SERVICE_KEY  = <service_role key>        (server-side only)

| Until both are present the integration stays DISABLED and every chat
| endpoint answers 503 instead of leaking data.
*/

return [

    'url' => env('SUPABASE_URL'),

    'service_key' => env('SUPABASE_SERVICE_KEY'),

    // Safety switch. Set SUPABASE_CHAT_ENABLED=false to take the whole
    // integration offline without touching .env credentials.
    'enabled' => env('SUPABASE_CHAT_ENABLED', true),

    'timeout' => (int) env('SUPABASE_TIMEOUT', 20),

    // Tables the backend is allowed to touch. Kept explicit so a typo in a
    // controller cannot silently address a wrong table.
    'tables' => [
        'messages' => 'messages',
        'conversations' => 'conversations',
        'app_users' => 'app_users',
    ],
];
