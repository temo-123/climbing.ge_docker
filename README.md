# climbing.ge — Docker

Containerizes the full stack: PHP 8.2-FPM (with the extensions the app's
composer packages need), Nginx, MySQL 8, Redis, a queue worker, the Laravel
scheduler, and (optional profiles) Horizon and a Node/`npm run watch` container.

## Layout

```
Software/
├── docker/                  # this repo
│   ├── docker-compose.yml
│   ├── .env.example         # copy to .env, controls container config
│   ├── php/
│   │   ├── Dockerfile       # multi-stage: composer → npm build → php-fpm runtime
│   │   ├── php.ini
│   │   ├── www.conf
│   │   └── entrypoint.sh
│   ├── nginx/conf.d/climbing.conf
│   └── mysql/init/          # drop .sql files here to auto-run on first DB boot
└── html/                    # Laravel application source (cloned separately)
```

The app source lives in `../html` and is bind-mounted into the containers, so
your normal edit/save workflow keeps working. `vendor/` and `node_modules/`
inside the container are separate named volumes (not the host folders) to
avoid host/container binary mismatches — the image seeds them on first run.

---

## First-time setup

### 1. Clone repos

```bash
cd /home/temo/Desktop/working/climbing.ge/Software

# Docker config (this repo)
git clone https://github.com/temo-123/climbing.ge-docker docker

# Application source
git clone https://github.com/temo-123/climbing.ge html
```

### 2. Configure environment

```bash
cd docker
cp .env.example .env
# Edit .env — set WWWUSER/WWWGROUP to match your host user:
#   id -u   → WWWUSER
#   id -g   → WWWGROUP
# Adjust DB credentials and ports as needed.
```

### 3. Build the Docker image

```bash
docker compose build
```

> The first build takes ~10 minutes — it compiles PHP extensions from source.
> Subsequent builds use the layer cache and are much faster.

### 4. Start containers

```bash
docker compose up -d
```

### 5. Run migrations and seed

```bash
docker compose exec app php artisan migrate --seed --force
```

### 6. Add local hostnames

Add to `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1 climbing.loc shop.climbing.loc blog.climbing.loc summit.climbing.loc films.climbing.loc user.climbing.loc forum.climbing.loc
```

### 7. Open the site

Visit `http://climbing.loc`

---

## Pulling latest code from Git

The `html/` directory is bind-mounted — pulling on the host is immediately reflected inside the containers.

```bash
cd /home/temo/Desktop/working/climbing.ge/Software/html
git pull
```

After pulling, run any of the following that apply:

**New migrations**
```bash
docker compose exec app php artisan migrate --force
```

**New or updated Composer packages** (`composer.json` / `composer.lock` changed)
```bash
docker compose exec app composer install --no-dev --optimize-autoloader
```

**New or updated npm packages or frontend assets** (`package.json` / `webpack.mix.js` changed)
```bash
docker compose exec app npm install
docker compose exec app npm run build
```

**Clear config / route / view cache** (when config files or routes changed)
```bash
docker compose exec app php artisan optimize:clear
```

---

## Common commands

### Containers

```bash
docker compose up -d                  # start all services
docker compose down                   # stop and remove containers
docker compose down -v                # stop + wipe DB / redis / vendor volumes
docker compose ps                     # show running containers
docker compose logs -f app            # stream app logs
docker compose logs -f queue          # stream queue worker logs
docker compose restart app            # restart a single service
```

### Laravel artisan

```bash
docker compose exec app php artisan tinker
docker compose exec app php artisan test
docker compose exec app php artisan migrate --force
docker compose exec app php artisan migrate:rollback
docker compose exec app php artisan migrate:fresh --seed --force
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan route:clear
docker compose exec app php artisan optimize:clear
docker compose exec app php artisan queue:work
```

### Database

```bash
# MySQL shell
docker compose exec mysql mysql -u root -p climbing_loc_db

# Dump the database
docker compose exec mysql mysqldump -u root -p climbing_loc_db > backup.sql

# Restore from dump
docker compose exec -T mysql mysql -u root -p climbing_loc_db < backup.sql
```

### Composer

```bash
# Install packages
docker compose exec app composer install --no-dev --optimize-autoloader

# Add a package
docker compose exec app composer require vendor/package

# Remove a package
docker compose exec app composer remove vendor/package
```

### Frontend assets

```bash
# One-off production build
docker compose exec app npm run build

# Watch for changes (development)
docker compose --profile dev up node

# Or run npm directly
docker compose exec app npm run watch
```

---

## Optional profiles

### Horizon (Redis queue dashboard)

```bash
# Set in .env or docker-compose.yml:
QUEUE_CONNECTION=redis

docker compose --profile horizon up -d horizon
```

### Node watch (live-reload during development)

```bash
docker compose --profile dev up node
```

---

## Notes

- **Laravel's `.env`** (`../html/.env`) is untouched — real container env vars
  (`DB_HOST=mysql`, `REDIS_HOST=redis`, etc., set in `docker-compose.yml`)
  take precedence over the file's values, so local (non-Docker) dev keeps working too.
- **Queue**: `QUEUE_CONNECTION=database` by default, handled by the `queue` service.
  Switch to Horizon by setting `QUEUE_CONNECTION=redis` and using the `horizon` profile.
- **Scheduler**: runs via `php artisan schedule:work` in its own container — no cron needed.
- **Frontend assets**: built once during `docker compose build` (multi-stage `npm run build`).
  For live-reload development, use the `dev` profile or run `npm run watch` on the host.
- **Migrations/seeds** are not run automatically — run them manually as shown above.
- Requires Docker Compose v2.17+ (uses `additional_contexts`) with BuildKit (default in current Docker).
