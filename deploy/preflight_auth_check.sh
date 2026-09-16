#!/bin/bash
# ============================================================================
# Nimiro - PRE-FLIGHT (READ ONLY) before enabling any RLS policy.
#
# Proves, from the live system, exactly who reads/writes Supabase and with
# which key, so no policy is enabled while the app still depends on anon.
#
# Run as ROOT: sudo bash preflight_auth_check.sh
# Changes NOTHING. Only reads files and issues HTTP GETs.
# ============================================================================
set -uo pipefail
APP=/var/www/shortzz
ANON_PUBLISHABLE="sb_publishable_BIDUnumhCjZ67pcm912jnQ_S8Hjso3I"
REF="qtdtetlyoakqfdwbgfiz"

hr(){ printf '\n=== %s ===\n' "$1"; }

hr "1. Is the app talking to Supabase directly?"
if grep -rq "supabase.co" "$APP" 2>/dev/null; then
  grep -rn "supabase.co" "$APP" 2>/dev/null | head -5
else
  echo "(none - server never calls Supabase directly)"
fi

hr "2. Are the credentials present (names only, NEVER values)?"
for v in SUPABASE_URL SUPABASE_SERVICE_KEY SUPABASE_CHAT_ENABLED; do
  if grep -q "^$v=" "$APP/.env" 2>/dev/null; then echo "  $v = SET"; else echo "  $v = not set"; fi
done

hr "3. BEFORE: can the PUBLIC key read the tables?"
for t in messages conversations app_users; do
  c=$(curl -s -o /dev/null -w '%{http_code}' \
      "https://$REF.supabase.co/rest/v1/$t?select=*&limit=1" \
      -H "apikey: $ANON_PUBLISHABLE" -H "Authorization: Bearer $ANON_PUBLISHABLE" --max-time 15)
  printf '  %-16s anon SELECT -> %s\n' "$t" "$c"
done

hr "4. Are the chat proxy routes live and protected?"
for r in fetchMyConversations fetchMessages sendMessage; do
  c=$(curl -s -o /dev/null -w '%{http_code}' -X POST "https://nimiro.chat/api/chat/$r" \
      -H 'Content-Type: application/json' -d '{}' --max-time 15)
  printf '  /api/chat/%-22s unauthenticated -> %s\n' "$r" "$c"
done

hr "5. What does the app still use Supabase/Firebase FOR?"
for pat in "cloud_firestore" "FirebaseAuth" "supabase_flutter"; do
  n=$(grep -rl "$pat" /var/www/shortzz 2>/dev/null | wc -l)
  echo "  server-side occurrences of $pat: $n"
done

echo ""
echo "PRE-FLIGHT DONE - nothing was modified."
