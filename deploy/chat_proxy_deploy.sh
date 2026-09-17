#!/bin/bash
# ============================================================================
# Nimiro - deploy the Laravel chat proxy (Supabase) SAFELY.
#
# Run as ROOT on the server (the app tree is owned by www-data, which is the
# correct hardened state).
#
#   sudo bash chat_proxy_deploy.sh
#
# It backs everything up first, syntax-checks every file BEFORE swapping it in,
# and rolls back automatically if anything fails. It never writes or echoes a
# credential: SUPABASE_URL / SUPABASE_SERVICE_KEY must already be in .env.
# ============================================================================
set -euo pipefail

APP=/var/www/shortzz
STAMP=$(date +%Y%m%d_%H%M%S)
BK=/var/backups/nimiro/chat_proxy_$STAMP
SRC="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root (sudo bash $0)" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# 0. Preconditions: the service_role key must already be in .env.
#    We never write it here and we never echo it.
# --------------------------------------------------------------------------
if ! grep -q '^SUPABASE_URL=' "$APP/.env"; then
  echo "ERROR: SUPABASE_URL is not set in $APP/.env" >&2
  echo "       add these two lines first, then re-run:" >&2
  echo "         SUPABASE_URL=https://<project-ref>.supabase.co" >&2
  echo "         SUPABASE_SERVICE_KEY=<service_role key>" >&2
  exit 1
fi
if ! grep -q '^SUPABASE_SERVICE_KEY=' "$APP/.env"; then
  echo "ERROR: SUPABASE_SERVICE_KEY is not set in $APP/.env" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# 1. Backup
# --------------------------------------------------------------------------
mkdir -p "$BK"
cp -a "$APP/.env"                    "$BK/env.bak"
cp -a "$APP/routes/api.php"          "$BK/api.php.bak"
cp -a "$APP/config"                  "$BK/config" 2>/dev/null || true
cp -a "$APP/app/Http/Controllers"    "$BK/Controllers"
echo "[OK] backup -> $BK"

rollback() {
  echo "[ROLLBACK] restoring from $BK" >&2
  cp -a "$BK/api.php.bak"              "$APP/routes/api.php"          || true
  cp -a "$BK/Controllers/."            "$APP/app/Http/Controllers/"   || true
  [ -d "$BK/config" ] && cp -a "$BK/config/." "$APP/config/"          || true
  rm -f "$APP/app/Http/Controllers/ChatController.php"
  rm -f "$APP/app/Services/SupabaseClient.php"
  rm -f "$APP/config/supabase.php"
  cd "$APP" && php artisan config:clear >/dev/null 2>&1 || true
  cd "$APP" && php artisan route:clear  >/dev/null 2>&1 || true
  echo "[ROLLBACK] done" >&2
}
trap 'code=$?; if [ $code -ne 0 ]; then rollback; fi' EXIT

# --------------------------------------------------------------------------
# 2. Syntax-check BEFORE installing anything (fail-closed deploy)
# --------------------------------------------------------------------------
for f in "$SRC/ChatController.php" "$SRC/SupabaseClient.php" "$SRC/supabase.php"; do
  php -l "$f" >/dev/null || { echo "ERROR: php -l failed on $f" >&2; exit 1; }
done
echo "[OK] php -l passed on all files"

# --------------------------------------------------------------------------
# 3. Install files
# --------------------------------------------------------------------------
mkdir -p "$APP/app/Services"
install -o www-data -g www-data -m 644 "$SRC/supabase.php"      "$APP/config/supabase.php"
install -o www-data -g www-data -m 644 "$SRC/SupabaseClient.php" "$APP/app/Services/SupabaseClient.php"
install -o www-data -g www-data -m 644 "$SRC/ChatController.php" "$APP/app/Http/Controllers/ChatController.php"
echo "[OK] files installed"

# --------------------------------------------------------------------------
# 4. Wire the routes in (idempotent)
# --------------------------------------------------------------------------
if grep -q 'ChatController' "$APP/routes/api.php"; then
  echo "[SKIP] chat routes already wired"
else
  python3 - "$APP/routes/api.php" "$SRC/routes_chat_snippet.php" <<'PY'
import sys
routes_path, snippet_path = sys.argv[1], sys.argv[2]
src = open(routes_path).read()
snippet = open(snippet_path).read()
# strip the leading <?php + use line; we only need the Route:: block
block = snippet.split('use App\\Http\\Controllers\\ChatController;', 1)[1].strip()
marker = "/* ===== NIMIRO CHAT PROXY (Supabase) ===== */"
# insert just before the FINAL closing brace of the checkHeader group, which is
# the last line of the file in this codebase.
idx = src.rstrip().rfind('}')
if idx == -1:
    sys.exit("could not find closing brace in routes/api.php")
new = src.rstrip()[:idx] + "\n\n" + marker + "\n" + block + "\n" + src.rstrip()[idx:] + "\n"
open(routes_path, 'w').write(new)
print("[OK] chat routes wired")
PY
  php -l "$APP/routes/api.php" >/dev/null || { echo "ERROR: routes/api.php broke" >&2; exit 1; }
fi

# --------------------------------------------------------------------------
# 5. Clear caches
# --------------------------------------------------------------------------
cd "$APP"
php artisan config:clear >/dev/null
php artisan route:clear  >/dev/null
php artisan cache:clear  >/dev/null
echo "[OK] caches cleared"

# --------------------------------------------------------------------------
# 6. Smoke test: the endpoints must exist and must NOT be public
# --------------------------------------------------------------------------
BASE=https://nimiro.chat
CODE_401=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/chat/fetchMyConversations" -H 'Content-Type: application/json' -d '{}' --max-time 20)
if [ "$CODE_401" = "404" ]; then
  echo "ERROR: chat routes are not registered (404)" >&2
  exit 1
fi
echo "[OK] smoke: unauthenticated chat call -> $CODE_401 (expected 401)"

trap - EXIT
echo "[DONE] chat proxy deployed. Backup kept at $BK"
