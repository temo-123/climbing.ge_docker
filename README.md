# climbing.ge — Docker

Containerizes the full stack: PHP 8.2-FPM (with the extensions the app's
composer packages need), Nginx, MySQL 8, Redis, a queue worker, the Laravel
scheduler, and (optional profiles) Horizon and a Node/`npm run watch` container.

## Layout

```
docker/
├── docker-compose.yml
├── .env.example        # copy to .env, controls container config
├── php/
│   ├── Dockerfile       # multi-stage: composer -> npm build -> php-fpm runtime
│   ├── php.ini
│   ├── www.conf
│   └── entrypoint.sh
├── nginx/conf.d/climbing.conf
└── mysql/init/          # drop .sql files here to auto-run on first DB boot
```

The app source lives in `../html` and is bind-mounted into the containers, so
your normal edit/save workflow keeps working. `vendor/` and `node_modules/`
inside the container are separate named volumes (not the host folders) to
avoid host/container binary mismatches — the image seeds them on first run.

## First run

```bash
cd /var/www/docker
cp .env.example .env        # adjust WWWUSER/WWWGROUP (run `id -u`/`id -g`), ports, DB creds
docker compose build
docker compose up -d
docker compose exec app php artisan migrate --seed
```

Add to `/etc/hosts` (pointing at wherever `APP_PORT` is published, `127.0.0.1` by default):

```
127.0.0.1 climbing.loc shop.climbing.loc blog.climbing.loc summit.climbing.loc films.climbing.loc user.climbing.loc forum.climbing.loc
```

Then visit `http://climbing.loc`.

## Notes

- **Laravel's `.env`** (`../html/.env`) is untouched — real container env vars
  (`DB_HOST=mysql`, `REDIS_HOST=redis`, etc., set in `docker-compose.yml`)
  take precedence over the file's values, so local (non-Docker) dev keeps working too.
- **Queue**: `QUEUE_CONNECTION=database` by default (matches the existing `.env`), handled by the `queue` service (`queue:work`). To use Horizon instead, set `QUEUE_CONNECTION=redis` and run `docker compose --profile horizon up -d horizon`.
- **Scheduler**: runs via `php artisan schedule:work` in its own container — no cron needed.
- **Frontend assets**: built once during `docker compose build` (multi-stage `npm run build`). For live-reload development, run `docker compose --profile dev up node` (`npm run watch`), or just run `npm run watch` on the host as before — both work against the same bind-mounted `../html`.
- **Migrations/seeds** are not run automatically — run them manually as shown above, matching the project's existing workflow.
- Requires Docker Compose v2.17+ (uses `additional_contexts`) with BuildKit (default in current Docker).

## Common commands

```bash
docker compose exec app php artisan tinker
docker compose exec app php artisan test
docker compose logs -f queue
docker compose exec mysql mysql -u root -p climbing_loc_db
docker compose down            # stop
docker compose down -v         # stop + wipe DB/redis/vendor volumes
```
