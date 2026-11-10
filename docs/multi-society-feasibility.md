# Feasibility study: running OAS for other societies

Status: draft for discussion (2026-11-10)

## Summary

Generalising OAS so other societies can use it is **feasible**, and the cheapest
safe route is **one isolated instance per society** (a "silo": its own container,
its own SQLite file, its own domain), not a shared multi-tenant database.

The domain model (members, memberships, trainings, attendance, credits, pricing,
transactions, GoCardless) is already generic. What ties the system to Oxfordshire
Acro Society is mostly *around* the model: branding text, domains, time zone,
currency, mail sender, deployment files and build-time React variables. Those are
a few weeks of part-time clean-up. True shared-database multi-tenancy would touch
nearly every query in the codebase and fight the SQLite choice, so it is not
recommended unless the number of societies grows into the dozens.

## How the system is shaped today

| Area | Current state | Multi-society impact |
|---|---|---|
| Database | SQLite via `ecto_sqlite3`, one file (`DB_FILE`), daily serialise-and-email backup (`Oas.Repo.backup/0`) | One file per society is natural. A shared file would put every society behind one writer lock. |
| Data access | ~550 `Oas.Repo` / `from(...)` call sites across ~52 modules, none scoped by tenant | Shared-DB tenancy would need a `society_id` on ~30 tables and a filter on every query. |
| Settings | Singleton rows: `config_config` (name, bacs, content, GoCardless keys, backup recipient...), `config_llm`, `config_tokens`, read with `limit: 1` | Already "per database", so per-society for free in a silo. |
| Background processes | Named singletons: `Oas.BackupJob`, `Oas.Trainings.RecurringServer`, `Oas.Gocardless.Supervisor` (Auth/Trans servers), named ETS tables `:user_table`, `:global_warnings` | Fine in a silo. In a shared app each would need a per-society registry/dynamic supervisor. |
| Realtime | Absinthe subscriptions keyed by e.g. `training_id`; Phoenix PubSub/Presence for chat | Fine in a silo. Shared app would need tenant-prefixed topics. |
| Auth | phx.gen.auth style member auth; roles are `is_admin` / `is_reviewer` booleans on `members`; cookie `domain` read with `Application.compile_env` | Silo: works, but the cookie domain is baked in at compile time (see below). |
| LLM chat | LangChain `ChatOpenAI` pointed at a self-hosted endpoint (`:llm_sudio_url`), model `qwen/qwen3-14b` hard-coded | Can be shared across societies, but capacity and cost become a question. |
| Frontends | Two CRA apps (`oas-web` admin, `oas-web-public`), URLs from `REACT_APP_*` at **build time** | Each society currently needs its own frontend build. |

## Society-specific assumptions found

**Branding and content**
- `oas-web-public/src/Home/Home.js`: "Oxfordshire Acro Society" heading and intro text.
- `oas-web-public/public/index.html`: page title and meta description.
- `oas-web-public/src/Static/Sjef2026.js`: a one-off Oxford event page (venue, prices, contact email). Should become CMS content or move out of the product.
- `Oas.Repo.backup/0`: email subject "OAS backup"; dev configs send as `{"OAS", "chris@oxfordshireacrosociety.co.uk"}`.
- No logo/colour theming hook in either frontend.

**Locale**
- Time zone `"Europe/London"` hard-coded in `Oas.Trainings.TrainingWhereTime` (`@time_zone`) and the GoCardless servers.
- Currency: "GBP" labels in `oas-web/src/Analysis/Analysis.js`; `£` in `oas-web/src/Member/whatsappDebtReminder.js`.
- `DEFAULT_COUNTRY_CODE = '44'` in the WhatsApp debt reminder.
- GoCardless Bank Account Data is UK/EEA only, so societies elsewhere would have no bank import (CSV import still works).

**Domains and deployment**
- `oxfordshireacrosociety.co.uk` hard-coded in `config/gcloud*.exs`, every `nginx/*.conf`, `Dockerfile_v3` (`ENV REACT_APP_*`), and the README run commands.
- Session and remember-me cookie `domain` use `Application.compile_env`, so it is fixed when the release is built, not when it starts.
- Prod/staging configs (`config/v2_prod.exs`, `config/v3_staging.exs`) are git-ignored and hold SMTP and secret-key settings. Each society would need its own copy, which does not scale by hand.
- The committed configs still run prod with `code_reloader: true` and `debug_errors: true` (`config/gcloud.exs`); worth fixing before anyone else's data is on it.
- Mail goes through a personal Gmail SMTP account; Gmail's sending limits and "from" rules make that unsuitable for several societies.

## Options

### A. Silo: one instance per society (recommended)

Each society gets its own container, SQLite file, backups, domain and secrets. The
code stays single-tenant; the work is making every society-specific value
configurable at runtime.

- **Pros:** almost no change to business logic; strong data isolation (bank data and
  member PII never share a file); a bad migration or crash only hits one society;
  matches the current SQLite + Docker setup; each society can be on its own release.
- **Cons:** N containers to patch and monitor; N GoCardless/LLM/SMTP setups; upgrades
  need a script that rolls through instances.
- **Fits:** a handful to a few dozen societies.

### B. Shared app, database per tenant

One BEAM node, routing by hostname to a per-society SQLite file via Ecto dynamic
repos (`Oas.Repo.put_dynamic_repo/1`).

- **Pros:** one deployment to run; isolation of data still good.
- **Cons:** every singleton GenServer, ETS table, PubSub topic and Absinthe topic
  must become per-tenant; the `limit: 1` config reads need a tenant cache; one crash
  or bad deploy hits everyone. Roughly 3 to 5 times the work of A.

### C. Shared app, shared database with `society_id`

- **Cons:** a column and filter on ~30 tables and ~550 query sites; one missed filter
  leaks one society's finances to another; SQLite's single writer becomes the
  bottleneck, so it effectively forces a move to Postgres. Not recommended at this
  scale.

## Work needed for option A

Ordered so each step is useful on its own, even for Oxfordshire alone.

1. **Runtime configuration** (small/medium)
   - Move prod settings out of git-ignored compile-time files into `config/runtime.exs`
     reading env vars (DB path, secret key base, SMTP, URLs, LLM endpoint).
   - Replace `Application.compile_env` for the cookie `domain` with runtime config.
   - Turn off `code_reloader`/`debug_errors` in prod.
2. **Society settings in the database** (small)
   - Add fields to `config_config` (or a new `config_society` row): display name,
     short name, contact email, time zone, currency code, default phone country
     code, logo URL, primary colour. Expose them in the admin Config screens and via
     a public GraphQL query.
   - Replace the hard-coded `"Europe/London"`, `GBP`/`£` and `'44'` with these.
3. **Frontend runtime config** (medium)
   - Stop baking `REACT_APP_*` URLs at build time: serve a small `/config.js` (or a
     GraphQL `publicConfig` query) so one build works for every society.
   - Read society name, logo and colours into the MUI theme and page title.
   - Move `Sjef2026.js` into CMS content (the existing `config.content` field or a
     simple pages table). Doing the CRA to Vite move first is optional; it does not
     block this.
4. **Mail** (small)
   - Per-society "from" name/address, sent through a transactional provider
     (Postmark, SES, Mailgun) rather than personal Gmail; Swoosh already supports these.
5. **Deployment and provisioning** (medium)
   - One parameterised Dockerfile and nginx template (domain from env), dropping
     the per-environment copies.
   - A `provision` script or mix task: create DB, run migrations, create the first
     admin (today this is a manual SQLite edit), seed config rows.
   - A roll-out script to upgrade all instances; per-instance health check and
     backup monitoring.
6. **LLM** (decision)
   - Either share the self-hosted endpoint with a per-society toggle (already exists
     via `config_llm.llm_enabled`) or let each society point at its own endpoint.

## Non-technical questions to settle first

- **Licence and model.** The README declares the code proprietary. Is this a hosted
  service you run for others (SaaS), or code they self-host? That decides who owns
  upgrades, backups and support.
- **Data protection.** Hosting other societies' member and bank data makes you a data
  processor under UK GDPR; you would need a data processing agreement, a privacy
  notice per society, and a breach process.
- **Banking.** Each society needs its own GoCardless Bank Account Data credentials
  and bank consent renewals (every 90 days).
- **Fit.** The model assumes acro-style training sessions, credits and memberships.
  It would be worth checking with one or two candidate societies whether that
  matches how they run, before generalising further.

## Suggested next step

Pilot with a single second society on option A. Steps 1 and 2 above are worth doing
for Oxfordshire anyway, and they are enough to stand up a second instance with its
own name, domain and time zone. Decide on B only if running many silos becomes the
real pain.
