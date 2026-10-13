# AI Usage

This project was built with the assistance of an AI coding assistant (GitHub Copilot, used as an agent inside VS Code). The AI proposed plans, drafted code and tests, and ran the verification commands. **The developer remained responsible for every engineering decision**: each plan was reviewed and explicitly approved before implementation, and each change was reviewed as a diff before it was committed.

## Evidence and scope of this document

- The Git history shows 16 commits from 2026-10-09 to 2026-10-14. The two documentation commits (requirements, architecture) precede the code; every later commit is one reviewed vertical slice (see the table below).
- Commits carry no AI trailers or tool metadata, so the history alone does not prove tool usage. This document is based on the development workflow and the artifacts in the repository.
- The prompts below are **representative prompts reconstructed from the workflow, not verbatim historical records**. They show the style and constraints used. No tool other than Copilot is claimed.

## 1. Workflow

Every feature followed the same loop:

1. **Plan only.** The prompt asked the AI to read `docs/requirements.md`, `docs/architecture.md` and the existing code, then propose files, constraints, risks and tests *without editing anything*.
2. **Human approval.** The developer approved, amended, or rejected the plan, often adding clarifications (for example "count increase events, not employees").
3. **Scoped implementation.** The AI implemented only the approved files, with explicit "do not" lists (no new dependencies, no unrelated refactors, no commit/push).
4. **Verification.** The AI ran RSpec, RuboCop and (for the frontend and deployment) Vitest, lint, build, Docker build and a container smoke test, and reported results.
5. **Review and fix.** A separate review prompt re-inspected the uncommitted diff for defects. Only real defects were fixed.
6. **Commit.** The developer committed after reviewing the diff.

| Commit | Slice |
|---|---|
| `fc2189d`, `a00bf31`, `14afcf9` | Requirements, architecture, inactive-employee rule clarification |
| `c59188d` | Employee model and DB constraints |
| `c0b405b` | SalaryRecord history and PostgreSQL constraints |
| `462a307` | Transactional `RecordSalaryChange` service |
| `cdd2e18`, `c3068c6`, `0ca849c` | Employee, Salary History and Insights APIs |
| `2c49fd5` | HR authentication, DB-backed sessions, CSRF, audit attribution |
| `632a994` | React/TypeScript/MUI frontend |
| `377e110` | Deterministic synthetic seed data (10,000 employees) |
| `292a25c`, `7f0a176`, `8d2e36c` | Docker deployment and two Docker build fixes |

## 2. Representative prompts

Each is a paraphrase of the kind of prompt used, not a transcript.

- **Requirements / architecture:** "Read the product requirements and propose an architecture for an HR salary tool: data model, API surface, auth, deployment. Flag ambiguities instead of guessing." The documented business-date rule (Asia/Kolkata) and inactive-employee rule came out of this, and `14afcf9` records a later clarification.
- **Models and constraints:** "Propose the SalaryRecord model, migration and model specs. Evaluate a PostgreSQL-backed approach to overlapping periods and explain trade-offs before choosing. Don't add controllers or services." This led to a GiST exclusion constraint on `[effective_from, effective_to)` per employee.
- **Salary business rules:** "Implement a transactional service that closes the current record and creates the new one. Pass the business date explicitly. Identify risks around concurrency and the error/result contract."
- **APIs:** "Implement Employee index/create/show/update with strong parameters, case-insensitive search with escaped `%`/`_`, capped pagination, and consistent 400/404/422 JSON errors." Later: "Return salary as a decimal string, never a float."
- **Insights:** "Use PostgreSQL window functions over the full history before applying the `[start, end)` range. Count increase events, not employees. Never combine currencies."
- **Authentication / security:** "Add `has_secure_password`, a database-backed session store (not CookieStore), session rotation on login, CSRF protection on all state-changing requests including login/logout, HttpOnly/SameSite=Lax/Secure cookies, and credentials from environment variables only." A follow-up prompt asked for a security review of the uncommitted diff.
- **React UI:** "Plan, then build a React + TS + MUI app against the existing API contracts only. Keep the CSRF token in memory, never localStorage; use decimal strings for money; label the insight metric exactly as the API defines it."
- **Tests:** each prompt required tests for the boundaries it introduced (salary precision, half-open date ranges, adjacent vs overlapping periods, anonymous 401, CSRF rejection, pagination limits).
- **Seed data:** "Create 10,000 synthetic, non-real employees with plausible, non-overlapping salary histories, attributed to the seeded HR user, idempotent on re-run, with specs."
- **Docker:** "Review the deployment config, then add a multi-stage build serving the React build through Rails, Compose with PostgreSQL and a health check, env-based config, explicit (not automatic) seeding, and a real README. Don't weaken auth or CSRF."
- **Troubleshooting:** pasted Docker build errors with an instruction such as "Make user creation robust when UID 1000 exists" and "ensure the directories exist before chown".

## 3. How prompts were refined

Prompts became more specific as problems appeared. Examples visible in the repository:

- Requirements clarification after the first architecture draft: inactive-employee salary rules (`14afcf9`).
- Constraint prompts grew from "no overlaps" to "evaluate DB-level options and explain trade-offs", then to review prompts asking for raw-SQL tests proving adjacent periods are accepted and overlaps across *different* employees are accepted.
- Insights wording was tightened from "count salary increases" to "count events, compare only with the immediately preceding record, same currency, full-history predecessor".
- Deployment review prompts progressively required: a mandatory host allow-list (a first version allowed any Host header), real asset content-type checks, passwords with URL-reserved characters, and an authenticated smoke test.
- Docker build failures were fixed in two small, separately committed steps: hardcoded UID/GID 1000 conflicts (`7f0a176`), then missing `log/` and `storage/` directories excluded by `.dockerignore` (`8d2e36c`).

## 4. Verification

AI output was never accepted on its own claim. Checks used:

- **Backend:** RSpec model, service, request and seed specs (161 examples at the last run) and RuboCop on `app config spec db`. Database constraints are tested with raw SQL, bypassing model validations.
- **Frontend:** Vitest + React Testing Library (12 tests), `oxlint`, and `npm run build`.
- **Seed data:** specs for counts, uniqueness, non-overlap, audit attribution and repeat-run idempotency; the development database was seeded and counted.
- **Deployment:** `docker build`, Docker Compose with a seeded database, and `bin/docker-smoke-test`, which verifies health, SPA deep links, asset content types, 404s for missing assets/unknown APIs, Secure/HttpOnly/SameSite cookies, login with and without the CSRF token, an authenticated request, and logout. `spec/production_config_spec.rb` boots the app in production mode to check host protection.
- **Review passes:** dedicated prompts re-read each uncommitted diff (SQL correctness, injection, CSRF coverage, secrets) and `git diff --check` before commit.

## 5. Decisions that required human review

- **Security:** server-side session store instead of cookie sessions, session rotation, CSRF on login/logout, CSRF token kept in memory in the frontend, host allow-list required in production, no secrets in Git or the image (`.env` and `master.key` are ignored by both Git and Docker).
- **Database constraints:** exclusion constraint vs model-only validation for overlap prevention; `numeric(19,3)` precision with matching model validation; the partial unique index for one open-ended record per employee.
- **Salary history rules:** half-open `[from, to)` periods, historical dates allowed, Asia/Kolkata business date, increase events counted rather than employees, currencies never mixed or converted, inactive employees excluded from current summaries but included in history.
- **Audit attribution:** recording the acting user required the `User` model first, so it was deferred until authentication existed rather than inventing a relationship earlier.
- **Deployment:** Rails serves the built frontend (simpler, but TLS still needs an external proxy); `SECRET_KEY_BASE` instead of `RAILS_MASTER_KEY`; migrate-only on start with explicit seeding (the seed resets the HR password, documented in the README).

## 6. Limitations and risks

| Risk | Mitigation |
|---|---|
| Plausible but wrong business logic (e.g. insight counting) | Written rules in `docs/`, explicit clarifications in prompts, boundary tests, review prompts |
| Security gaps (CSRF, cookies, host checks) | Dedicated security review, negative tests, production-mode config spec, container smoke test |
| Tests that only confirm the AI's own assumptions | DB-level raw-SQL tests; independent end-to-end smoke test against a running container |
| Scope creep and unrelated edits | "Plan only" step, explicit file lists, `git status`/diff review before each commit |
| Environment-specific failures (Docker users, ignored directories) | Docker builds run after each change; failures fixed with targeted commits |
| Secrets leaking into prompts or output | Secrets read from environment only; throwaway random values for tests; credentials never printed |

Known remaining limitations: the smoke test was run over plain HTTP against `localhost` (no real TLS proxy was exercised), and a pre-existing RuboCop offense in `Gemfile` was deliberately left untouched.
