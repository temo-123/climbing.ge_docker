#!/bin/sh
set -e

# Wait for MySQL to accept connections before doing anything DB-related
if [ -n "$DB_HOST" ]; then
  echo "Waiting for MySQL at ${DB_HOST}:${DB_PORT:-3306}..."
  tries=0
  until php -r "new PDO('mysql:host=${DB_HOST};port=${DB_PORT:-3306}', '${DB_USERNAME}', '${DB_PASSWORD}');" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      echo "MySQL did not become ready in time, continuing anyway."
      break
    fi
    sleep 1
  done
fi

if [ ! -f /var/www/html/.env ] && [ -f /var/www/html/.env.example ]; then
  cp /var/www/html/.env.example /var/www/html/.env
fi

if [ -f /var/www/html/artisan ]; then
  APP_KEY_SET=$(php artisan tinker --execute="echo config('app.key') ? 1 : 0;" 2>/dev/null || echo 0)
  if [ "$APP_KEY_SET" != "1" ]; then
    php artisan key:generate --force || true
  fi

  if [ ! -e /var/www/html/public/storage ]; then
    php artisan storage:link || true
  fi
fi

echo "Note: run migrations manually, e.g.:"
echo "  docker compose exec app php artisan migrate --seed"

exec "$@"
