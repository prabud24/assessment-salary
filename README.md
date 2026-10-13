# Salary Management

HR salary-management application: a Rails 7.2 API (Ruby 3.3.2, PostgreSQL) and a React + TypeScript + MUI frontend (`frontend/`). In production Rails serves the built frontend and the `/api/v1` API from a single origin. See `docs/requirements.md` and `docs/architecture.md` for the specification and design.

## Local development

Requirements: Ruby 3.3.2, Node 22.14.0 (`.nvmrc`), PostgreSQL.

```sh
bundle install
bin/rails db:create db:migrate
HR_MANAGER_EMAIL=hr@example.test HR_MANAGER_PASSWORD='choose-a-password' bin/rails db:seed
bin/rails server            # API on :3000

cd frontend && npm ci && npm run dev   # Vite proxies /api to :3000
```

`config/database.yml` holds the local development/test connection settings (user, port 5433); adjust them for your machine. Production reads either `DATABASE_URL` or the discrete `DB_HOST`/`POSTGRES_*` variables.

## Tests and linting

```sh
bundle exec rspec
bundle exec rubocop
cd frontend && npm test && npm run lint && npm run build
```

## Docker

`docker-compose.yml` runs PostgreSQL (persistent `postgres_data` volume, health-checked) and the app image (multi-stage: Node builds the frontend, the Ruby image serves it from `public/`; unknown non-API HTML routes fall back to `index.html` so deep links work).

```sh
cp .env.example .env     # then fill in the values; .env is git-ignored
docker compose up -d --build
docker compose --profile tools run --rm seed    # explicit, one-off
```

Open http://localhost:3000 (change with `APP_PORT`). After seeding, verify the running stack (login with the CSRF flow, assets, SPA fallback, 404s) with `BASE_URL=http://localhost:3000 bin/docker-smoke-test`; it reads `HR_MANAGER_EMAIL`/`HR_MANAGER_PASSWORD` from the environment and never prints them. Secure session cookies work on `localhost`; any other hostname must be served over HTTPS.

### Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `POSTGRES_PASSWORD` | yes | Database password. Any characters are allowed: Compose passes it to Rails as a discrete variable, not inside a URL |
| `SECRET_KEY_BASE` | yes | Signs/encrypts Rails data. Generate: `openssl rand -hex 64`. Replaces `RAILS_MASTER_KEY`; `config/master.key` is never needed or copied into the image |
| `POSTGRES_USER`, `POSTGRES_DB` | no | Default `salary` / `assessment_salary_production` |
| `DB_HOST`, `DB_PORT` | set by Compose (`db`, 5432) | Database host/port, used with `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` |
| `DATABASE_URL` | no | Optional override for an external/managed database (`postgres://user:pass@host:5432/db`; percent-encode reserved characters in the password). Takes precedence over the variables above |
| `HR_MANAGER_EMAIL`, `HR_MANAGER_PASSWORD` | for seeding | Initial HR login; `db:seed` aborts if either is missing |
| `RAILS_ALLOWED_HOSTS` | yes (production) | Comma-separated hostnames the app is served from (e.g. `salary.example.com`). Production refuses to boot without it and answers other `Host` headers with 403. Compose defaults to `localhost`. `/up` is always exempt |
| `RAILS_LOG_LEVEL`, `APP_PORT`, `RAILS_MAX_THREADS` | no | Logging, published port, DB pool/threads |

### Database initialisation and seeding

- On start the container runs `db:migrate` only. It never seeds, resets or drops data, so restarts are safe.
- Seeding is an explicit command (above). It creates 10,000 synthetic employees with salary histories, and is idempotent: reruns add nothing. Note it **sets the HR user's password to the current `HR_MANAGER_PASSWORD`**, which is also how you rotate it.
- To wipe everything (destructive): `docker compose down -v`.

## Security and deployment notes

- Production forces SSL and assumes TLS terminates at a reverse proxy/platform that sets `X-Forwarded-Proto: https`. The session is stored in PostgreSQL; the cookie is `HttpOnly`, `Secure`, `SameSite=Lax`. HTTPS is mandatory for any public deployment.
- All state-changing requests (including login and logout) require the CSRF token from `GET /api/v1/session`, sent as `X-CSRF-Token`; the frontend keeps it in memory only.
- All employee, salary and insights endpoints require an authenticated HR user (401 otherwise). `/up` and `/api/v1/health` are public.
- Never commit `.env`, `config/master.key`, or credentials. Passwords are stored hashed (bcrypt) and request parameters such as passwords and emails are filtered from logs.
- Public deployment (TLS, managed Postgres, secrets, running the seed) is not performed by this repository; follow the steps above on the chosen platform, using the same image.
