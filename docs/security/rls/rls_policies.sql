-- ============================================================================
--  Nimiro — Supabase RLS Lockdown
--  Project ref : qtdtetlyoakqfdwbgfiz
--  Targets     : public.messages , public.conversations , public.app_users
--  Version     : v1  (2026-09-16)
-- ----------------------------------------------------------------------------
--  HOW TO RUN
--    Supabase Dashboard  ->  SQL Editor  ->  New query  ->  paste  ->  Run
--
--  !!! IMPORTANT !!!
--    The `service_role` key is a PostgREST DATA key. It can read/write rows,
--    but it CANNOT run DDL (ALTER TABLE / CREATE POLICY). Running this file
--    "with the service_role key" is technically impossible -- it must be run
--    from the SQL Editor (or any real Postgres connection as `postgres`).
-- ============================================================================


-- ============================================================================
-- SECTION 0 — PRE-FLIGHT (read-only, save the output first)
-- ============================================================================
-- 0.1 Is RLS already on? (expect: rowsecurity = false -> the hole is open)
SELECT tablename, rowsecurity, forcerowsecurity
FROM   pg_tables
WHERE  schemaname = 'public'
  AND  tablename IN ('messages', 'conversations', 'app_users')
ORDER  BY tablename;

-- 0.2 What can the anonymous role actually do right now?
--     (expect: SELECT/INSERT/UPDATE/DELETE = YES for anon -> fully exposed)
SELECT table_name, grantee, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM   information_schema.role_table_grants
WHERE  table_schema = 'public'
  AND  table_name IN ('messages', 'conversations', 'app_users')
  AND  grantee IN ('anon', 'authenticated', 'service_role')
GROUP  BY table_name, grantee
ORDER  BY table_name, grantee;

-- 0.3 Row counts BEFORE (expect 62 / 31 / 18)
SELECT 'messages' AS t, count(*) FROM public.messages
UNION ALL SELECT 'conversations', count(*) FROM public.conversations
UNION ALL SELECT 'app_users',     count(*) FROM public.app_users;


-- ============================================================================
-- SECTION 1 — BACKUP
-- ============================================================================
--  A full JSON export was taken before touching anything:
--    documents/nimiro-rls-lockdown/backup/{messages,conversations,app_users}.json
--    documents/nimiro-rls-lockdown/backup/CHECKSUMS.txt   (sha256, verified OK)
--
--  Prefer a server-side snapshot too:
--    Dashboard -> Database -> Backups -> "Create backup"  (do this first)


-- ============================================================================
-- SECTION 2 — PHASE 1 : CLOSE THE PUBLIC HOLE
-- ----------------------------------------------------------------------------
--  Pick ONE of the two options below. Do not run both.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- OPTION A  (RECOMMENDED) — full lockdown: nobody reads, nobody writes.
--   Closes both the read leak (62 messages / 18 users with e-mails) and the
--   write leak (anonymous INSERT + DELETE, both proven on the live project).
--   CONSEQUENCE: the Flutter app talks to Supabase directly with the
--   publishable key and has NO Supabase session for e-mail/password logins,
--   so chat reads/writes will be DENIED until either
--     (a) chat is routed through the Laravel backend using a server-side
--         service_role key (recommended), or
--     (b) Phase 2 + a minimal app change lands (see Section 4).
-- ---------------------------------------------------------------------------
BEGIN;

ALTER TABLE public.messages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_users     ENABLE ROW LEVEL SECURITY;

-- Remove the blanket table grants from the two public-facing roles.
REVOKE ALL ON TABLE public.messages      FROM anon, authenticated;
REVOKE ALL ON TABLE public.conversations FROM anon, authenticated;
REVOKE ALL ON TABLE public.app_users     FROM anon, authenticated;

COMMIT;


-- ---------------------------------------------------------------------------
-- OPTION B  — fallback, ONLY if the app truly cannot be changed right now.
--   Closes WRITES (INSERT/UPDATE/DELETE) but leaves READS open.
--   !! The read exposure REMAINS: anyone with the app key can still read
--   !! every message and every user e-mail. Use this as a stop-gap, not a fix.
-- ---------------------------------------------------------------------------
-- (run this block instead of Option A)
--
-- BEGIN;
--
-- ALTER TABLE public.messages      ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.app_users     ENABLE ROW LEVEL SECURITY;
--
-- REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
--   ON TABLE public.messages, public.conversations, public.app_users
--   FROM anon, authenticated;
--
-- -- temporary read-through policies (remove them once the app is updated)
-- CREATE POLICY tmp_read_messages      ON public.messages      FOR SELECT TO anon, authenticated USING (true);
-- CREATE POLICY tmp_read_conversations ON public.conversations FOR SELECT TO anon, authenticated USING (true);
-- CREATE POLICY tmp_read_app_users     ON public.app_users     FOR SELECT TO anon, authenticated USING (true);
--
-- COMMIT;


-- ============================================================================
-- SECTION 3 — PHASE 1 VERIFICATION (run after Section 2)
-- ============================================================================
-- 3.1 RLS must now read `true`
SELECT tablename, rowsecurity
FROM   pg_tables
WHERE  schemaname = 'public'
  AND  tablename IN ('messages', 'conversations', 'app_users')
ORDER  BY tablename;

-- 3.2 anon must have NO privileges left (expect: zero rows for anon)
SELECT table_name, grantee, privilege_type
FROM   information_schema.role_table_grants
WHERE  table_schema = 'public'
  AND  table_name IN ('messages', 'conversations', 'app_users')
  AND  grantee = 'anon';

-- 3.3 Row counts must be UNCHANGED (expect 62 / 31 / 18)
SELECT 'messages' AS t, count(*) FROM public.messages
UNION ALL SELECT 'conversations', count(*) FROM public.conversations
UNION ALL SELECT 'app_users',     count(*) FROM public.app_users;

-- 3.4 From OUTSIDE (replace <PUBLISHABLE_KEY>), the API must now answer
--     401 "permission denied" instead of 200:
--
-- curl -s -o /dev/null -w "%{http_code}\n" \
--   -H "apikey: <PUBLISHABLE_KEY>" -H "Authorization: Bearer <PUBLISHABLE_KEY>" \
--   "https://qtdtetlyoakqfdwbgfiz.supabase.co/rest/v1/messages?select=*&limit=1"
--
--   before: 200 + 62 rows      after (Option A): 401


-- ============================================================================
-- SECTION 4 — PHASE 2 : OWNER-ONLY POLICIES
-- ----------------------------------------------------------------------------
--  PREREQUISITE — read this before running anything here.
--
--  The app authenticates with FIREBASE AUTH (e-mail/password) and only uses
--  Supabase Auth for Google/Apple OAuth. There is therefore NO link between a
--  Supabase auth user and a Nimiro `user_id`. Policies that rely on auth.uid()
--  will match nothing until that link exists.
--
--  Requirements before enabling Section 4:
--    (1) add `auth_id uuid` to app_users and have the app write it at login;
--    (2) decide how GUEST users (4 of the 18 rows have `guest_*` identities
--        and no e-mail) get a session -> signInAnonymously(), or route guest
--        traffic through the Laravel backend;
--    (3) validate on a Supabase branch / staging project first. The live rows
--        are not self-consistent: `doc_id` is reversed relative to `user_id`
--        (e.g. row with doc_id = "18_23" carries user_id = 18) and
--        `other_user_id` repeats `user_id`. Do NOT assume the obvious join.
-- ============================================================================

-- 4.1 the auth link column
-- ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS auth_id uuid;
-- CREATE UNIQUE INDEX IF NOT EXISTS app_users_auth_id_key
--   ON public.app_users (auth_id) WHERE auth_id IS NOT NULL;

-- 4.2 helpers (SECURITY DEFINER so the policies don't recurse through RLS)
-- CREATE OR REPLACE FUNCTION public.current_nimiro_user_id()
-- RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
-- AS $$ SELECT u.user_id FROM public.app_users u WHERE u.auth_id = auth.uid() LIMIT 1; $$;
--
-- CREATE OR REPLACE FUNCTION public.is_conversation_participant(p_conversation_id text)
-- RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
-- AS $$
--   SELECT EXISTS (
--     SELECT 1 FROM public.conversations c
--     WHERE c.conversation_id = p_conversation_id
--       AND (c.user_id = public.current_nimiro_user_id()
--            OR c.other_user_id = public.current_nimiro_user_id())
--   );
-- $$;
--
-- REVOKE ALL ON FUNCTION public.current_nimiro_user_id()             FROM PUBLIC;
-- REVOKE ALL ON FUNCTION public.is_conversation_participant(text)    FROM PUBLIC;
-- GRANT EXECUTE ON FUNCTION public.current_nimiro_user_id()          TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.is_conversation_participant(text) TO authenticated;

-- 4.3 re-grant table access to logged-in users only
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages, public.conversations TO authenticated;
-- GRANT SELECT, UPDATE                ON public.app_users                      TO authenticated;

-- 4.4 policies — app_users
-- CREATE POLICY app_users_select_self ON public.app_users FOR SELECT TO authenticated
--   USING (auth_id = auth.uid() OR user_id = public.current_nimiro_user_id());
-- CREATE POLICY app_users_update_self ON public.app_users FOR UPDATE TO authenticated
--   USING (auth_id = auth.uid()) WITH CHECK (auth_id = auth.uid());

-- 4.5 policies — conversations
-- CREATE POLICY conversations_select_own ON public.conversations FOR SELECT TO authenticated
--   USING (user_id = public.current_nimiro_user_id() OR other_user_id = public.current_nimiro_user_id());
-- CREATE POLICY conversations_insert_own ON public.conversations FOR INSERT TO authenticated
--   WITH CHECK (user_id = public.current_nimiro_user_id());
-- CREATE POLICY conversations_update_own ON public.conversations FOR UPDATE TO authenticated
--   USING (user_id = public.current_nimiro_user_id()) WITH CHECK (user_id = public.current_nimiro_user_id());
-- CREATE POLICY conversations_delete_own ON public.conversations FOR DELETE TO authenticated
--   USING (user_id = public.current_nimiro_user_id());

-- 4.6 policies — messages (only inside rooms you belong to)
-- CREATE POLICY messages_select_mine ON public.messages FOR SELECT TO authenticated
--   USING (public.is_conversation_participant(conversation_id));
-- CREATE POLICY messages_insert_mine ON public.messages FOR INSERT TO authenticated
--   WITH CHECK (user_id = public.current_nimiro_user_id()
--               AND public.is_conversation_participant(conversation_id));
-- CREATE POLICY messages_update_mine ON public.messages FOR UPDATE TO authenticated
--   USING (user_id = public.current_nimiro_user_id()) WITH CHECK (user_id = public.current_nimiro_user_id());
-- CREATE POLICY messages_delete_mine ON public.messages FOR DELETE TO authenticated
--   USING (user_id = public.current_nimiro_user_id());

-- 4.7 remember: `service_role` bypasses RLS by design -> never ship it in the app.
--     It belongs in the Laravel .env only.


-- ============================================================================
-- SECTION 5 — ROLLBACK (only if something breaks)
-- ============================================================================
-- BEGIN;
-- DROP POLICY IF EXISTS app_users_select_self     ON public.app_users;
-- DROP POLICY IF EXISTS app_users_update_self     ON public.app_users;
-- DROP POLICY IF EXISTS conversations_select_own  ON public.conversations;
-- DROP POLICY IF EXISTS conversations_insert_own  ON public.conversations;
-- DROP POLICY IF EXISTS conversations_update_own  ON public.conversations;
-- DROP POLICY IF EXISTS conversations_delete_own  ON public.conversations;
-- DROP POLICY IF EXISTS messages_select_mine      ON public.messages;
-- DROP POLICY IF EXISTS messages_insert_mine      ON public.messages;
-- DROP POLICY IF EXISTS messages_update_mine      ON public.messages;
-- DROP POLICY IF EXISTS messages_delete_mine      ON public.messages;
-- DROP POLICY IF EXISTS tmp_read_messages         ON public.messages;
-- DROP POLICY IF EXISTS tmp_read_conversations    ON public.conversations;
-- DROP POLICY IF EXISTS tmp_read_app_users        ON public.app_users;
--
-- ALTER TABLE public.messages      DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.conversations DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.app_users     DISABLE ROW LEVEL SECURITY;
--
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.messages, public.conversations, public.app_users TO anon, authenticated;
-- COMMIT;
--
-- !! Rollback re-opens the leak. Use it only to restore service, then fix forward.
-- ============================================================================
