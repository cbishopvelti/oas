# OAS operator guide

How to build, run, set up and look after an OAS server for a society. Every
fact here comes from the code on `feat/multi-society` and from
[README_v3.md](../README_v3.md). Sections marked **To be written** depend on
hosting decisions that have not been made yet.

Contents:

1. [How it fits together](#1-how-it-fits-together)
2. [Building the image](#2-building-the-image)
3. [Running a society](#3-running-a-society)
4. [Setting up a new society](#4-setting-up-a-new-society)
5. [Environment variables](#5-environment-variables)
6. [The Config screen](#6-the-config-screen)
7. [Upgrading](#7-upgrading)
8. [Backups](#8-backups)
9. [Health check](#9-health-check)
10. [Rotating SECRET_KEY_BASE](#10-rotating-secret_key_base)
11. [Troubleshooting](#11-troubleshooting)
12. [Several societies on one machine](#12-several-societies-on-one-machine)
13. [Rolling out to every society](#13-rolling-out-to-every-society)

---

## 1. How it fits together

One container runs one society. Inside it:

- **Phoenix** (the server) listens on port 4000. It serves the GraphQL API,
  the sockets, the log in and password pages, `/api/config.js` and `/health`.
  It is started in a tmux session called `server` by `docker_v2.sh`, which
  runs `mix ecto.migrate` first.
- **nginx** listens on port 80 and picks the app by host name
  (`nginx/v3_nginx.conf`):
  - `server.<domain>` proxies everything (including `/socket/` and
    `/public_socket/`) to Phoenix.
  - `admin.<domain>` serves the admin React app (`oas-web/build`) and proxies
    `/api` to Phoenix.
  - any other host (normally `www.<domain>`) serves the public booking app
    (`oas-web-public/build`) and proxies `/api` to Phoenix.
- **SQLite** holds all the data in one file (`DB_FILE`). Back it up by
  mounting its folder as a volume.

So a society needs three host names on one parent domain: `server.`, `admin.`
and `www.` (or another name for the public site). They must share a parent
domain because the login cookie is set on that parent (`DOMAIN`), see
[Login across subdomains](#login-does-not-stick-across-subdomains).

The React apps have no URLs baked in. They load `/api/config.js` at start,
which tells them the server, admin and public URLs from the server's own
settings.

## 2. Building the image

One image serves any society. No URLs, domains or society names are baked in.

```
docker build . \
  --build-arg MIX_ENV=v2_prod \
  -f Dockerfile_v3 -t chrisjbishop155/oas:v3_prod

docker push chrisjbishop155/oas:v3_prod
```

- `MIX_ENV` picks the compile-time config file (`config/<MIX_ENV>.exs`, e.g.
  `v2_prod` or `v3_staging`). Those two files are git-ignored and hold
  Oxfordshire's settings, so only the person who has them can build those
  images. Every value they set can be overridden at run time (see
  [Environment variables](#5-environment-variables)).
- The build runs `npm install` and `npm run build` for both React apps,
  `mix compile`, and `mix esbuild default --minify` for the Phoenix pages'
  JS and CSS. Keep that esbuild step if you edit the Dockerfile.
- Staging builds the same way with `--build-arg MIX_ENV=v3_staging` and the
  tag `v3_staging`.

To check no Oxfordshire text has slipped into the React builds:

```
scripts/check-no-oxfordshire.sh            # builds both apps, then searches
scripts/check-no-oxfordshire.sh --skip-build
```

## 3. Running a society

Put the society's settings in an env file outside git (e.g.
`/etc/oas/society.env`, copied from [.env.example](../.env.example)) and pass
it with `--env-file`. The run command used for Oxfordshire is:

```
docker stop oas; docker rm oas; \
docker run -it -d \
  --name=oas \
  --restart unless-stopped \
  --env-file /etc/oas/society.env \
  -e MIX_ENV=v2_prod \
  -p 80:80 -p 443:443 \
  -v /path/on/host/oas-dbs:/dbs \
  -v /oas-dbs-backup:/oas-dbs-backup \
  -v /path/on/host/gocardless_backup:/gocardless_backup \
  --add-host host.docker.internal:host-gateway \
  chrisjbishop155/oas:v3_prod
```

- Mount the folders that hold `DB_FILE`, `DB_BACKUP_PATH` and
  `GOCARDLESS_BACKUP_DIR`, or the data is lost when the container is removed.
- `--add-host host.docker.internal:host-gateway` lets the LLM chat reach a
  model server running on the host (`LLM_STUDIO_URL`).
- The container is started with `-it` because `docker_v2.sh` ends in a shell.
  To see the server's console and logs:
  `docker exec -it oas tmux attach -t server` (detach with `Ctrl-b d`).
- At start-up the server logs which settings came from the environment and
  which from the config file (names only, never values). Check this line
  first when something looks like another society's value.

**TLS:** the image includes certbot and its nginx plugin. With the old v2
image certificates were set up by running `certbot --nginx` inside the
container. How TLS is done for v3, and whether it lives in the container or in
a proxy in front of it, is **to be written** once hosting is decided (see
[section 12](#12-several-societies-on-one-machine)).

## 4. Setting up a new society

On a new, empty database, run `mix oas.provision` once inside the running
container. It uses the container's environment, so the link it prints points
at the right host.

```
docker exec -it oas mix oas.provision \
  --name "Bristol Acro" \
  --time-zone Europe/London \
  --currency GBP \
  --admin-email admin@bristolacro.example \
  --admin-name "Sam Smith"
```

What it does:

1. Runs the migrations.
2. Sets the society name, time zone and currency, checked the same way as
   the admin Config screen (a real time zone name, a three-letter upper case
   currency code).
3. Creates the first admin, unless a member with that email already exists.
4. Prints a link for that admin to set their password. It is the same link
   the reset password email sends and is valid for **one day**. Nothing is
   emailed, and no password is ever passed in or printed. Don't share the
   link.

Details:

- All five options are required. If any value is invalid nothing is saved.
- Running it again with the same values changes nothing and prints
  `Nothing changed.`
- If the link expired before it was used, run it again with `--new-link` to
  print a fresh one for the existing admin.
- If a member with that email exists but is not an admin, it leaves them
  alone and says so. Make them an admin from the admin site, or use another
  email.
- It does not start the web server, so it is safe to run while the server is
  up.

Then log in to the admin site as that admin and fill in the rest on the
[Config screen](#6-the-config-screen): logo, colour, contact email, backup
recipient and so on. Send a test email from there to check mail works.

## 5. Environment variables

All are optional and read at start-up by `config/runtime.exs`. A variable that
is set and not empty replaces the value from the config file the image was
built with. Unset or empty keeps the file's value. A change needs a container
restart, not a rebuild. The full annotated list is
[.env.example](../.env.example).

**A second society must set** the ones marked ✱. Anything it leaves unset is
inherited from the Oxfordshire config file in the prod image, including the
secret key.

### Database and backups

| Variable | What it sets | Notes |
|---|---|---|
| `DB_FILE` ✱ | SQLite database file | e.g. `/dbs/sqlite-prod.db`, inside a mounted folder. |
| `DB_BACKUP_PATH` | Backup path prefix | `-<UTC timestamp>.db` is appended, e.g. `/oas-dbs-backup/sqlite-backup`. Set it for a second society so backups don't mix. |
| `BACKUP_TIME` | Daily backup time | `HH:MM` 24 hour, in the society time zone. Default `03:00`. Anything else stops the server at start-up. |
| `BACKUP_KEEP_DAYS` | Days to keep backups on disk | Default `30`. `0` never deletes. Must be a whole number, 0 or more. |

### Web server

| Variable | What it sets | Notes |
|---|---|---|
| `SECRET_KEY_BASE` ✱ | Signs cookies and sockets | Generate with `mix phx.gen.secret`. Must be unique per society, or login cookies from one society work on another. |
| `PHX_HOST` ✱ | Host name the server builds URLs for | e.g. `server.bristolacro.example`. Used in emailed links and by `mix oas.provision`. |
| `PORT` | Port Phoenix listens on | Default 4000. Leave it alone in the v3 image: nginx and the Docker health check both use 4000. |
| `DOMAIN` ✱ | Cookie domain | Parent domain with a leading dot, e.g. `.bristolacro.example`. The v3 image does not set it; without it the cookie domain falls back to `localhost`. |
| `ADMIN_URL` ✱ | Admin app URL | e.g. `https://admin.bristolacro.example`. Used in emails, redirects, links and the origin check. The old name `REACT_APP_ADMIN_URL` still works; `ADMIN_URL` wins. |
| `PUBLIC_URL` ✱ | Public booking site URL | e.g. `https://www.bristolacro.example`. As above; old name `REACT_APP_PUBLIC_URL`. |
| `ALLOW_ANY_ORIGIN` | Turns the origin check off | `true` accepts browser requests and sockets from any origin. For debugging only; don't leave it on. |

`ADMIN_URL` and `PUBLIC_URL` must match what the browser shows exactly,
scheme and port included. Outside dev and test the server only accepts
browser (CORS) and socket requests from those two and from its own host
(`PHX_HOST`, host only).

### Email

These apply to both mailers: `Oas.Mailer` (notifications, backups, test email)
and `Oas.TokenMailer` (password reset and confirmation emails).

| Variable | What it sets | Notes |
|---|---|---|
| `MAIL_ADAPTER` | How mail is sent | `smtp` sends through the `SMTP_*` settings. `local` keeps mail in memory and sends nothing (staging, trials). Anything else stops the server at start-up. Unset keeps the config file's adapter, which can differ between the two mailers. A second society should set `smtp`. |
| `SMTP_RELAY` | SMTP host | e.g. `smtp.gmail.com` or a provider's host. |
| `SMTP_PORT` | SMTP port | Usually `587`. |
| `SMTP_USERNAME` | SMTP user | Often an API key with a transactional provider. |
| `SMTP_PASSWORD` | SMTP password | |
| `SMTP_TLS` | STARTTLS | `always`, `if_available` or `never`. Use `always` on port 587. |
| `MAIL_FROM_ADDRESS` ✱ | From address of every email | Must be on a domain the SMTP account may send from. |
| `MAIL_FROM_NAME` | From name | Optional. Defaults to the society name from Config. Needs `MAIL_FROM_ADDRESS` set too, or the server stops at start-up. |

Reply-To is the contact email from the Config screen, when set. For a society
with many members, use a transactional provider (Brevo, Postmark, Mailgun,
Amazon SES, SendGrid) rather than a personal Gmail account, which limits
emails per day. Verify the sending domain with the provider (SPF and DKIM DNS
records) and put its SMTP details in the `SMTP_*` variables. No code change is
needed.

### Integrations

| Variable | What it sets | Notes |
|---|---|---|
| `LLM_STUDIO_URL` | OpenAI-compatible chat completions URL for the LLM chat | e.g. `http://host.docker.internal:1234/v1/chat/completions`. |
| `LLM_MODEL` | Model name sent to that URL | Default `qwen/qwen3-14b`. |
| `GOCARDLESS_BACKUP_DIR` | Folder for GoCardless transaction backups | e.g. `/gocardless_backup`, mounted. |

### Minimal env file for a second society

```
SECRET_KEY_BASE=<output of mix phx.gen.secret>
DB_FILE=/dbs/bristol.db
DB_BACKUP_PATH=/oas-dbs-backup/bristol-backup
PHX_HOST=server.bristolacro.example
DOMAIN=.bristolacro.example
ADMIN_URL=https://admin.bristolacro.example
PUBLIC_URL=https://www.bristolacro.example
MAIL_ADAPTER=smtp
SMTP_RELAY=smtp.example-provider.com
SMTP_PORT=587
SMTP_TLS=always
SMTP_USERNAME=...
SMTP_PASSWORD=...
MAIL_FROM_ADDRESS=bookings@bristolacro.example
```

Add `GOCARDLESS_BACKUP_DIR` and `LLM_*` if the society uses those features.

## 6. The Config screen

Society settings live in the database, not in environment variables, and are
edited by an admin in the admin site under Config. Changes apply straight
away; no restart is needed.

**Config** (`/config`):

| Field | Notes |
|---|---|
| Society name (for emails) | Shown across the sites and used as the email From name (unless `MAIL_FROM_NAME` is set). Also names the emailed backup file. |
| Short name | e.g. `OAS`. |
| Public site title | Title of the public booking site. |
| Contact email | Reply-To on every email. |
| Time zone | A time zone name such as `Europe/London`. Dates, booking times and the backup time use it. |
| Currency | Three-letter code, e.g. `GBP`. |
| Phone country code | Digits only, no `+`, 1 to 4 digits. |
| Logo URL | Logo shown on the sites. |
| Primary colour | `#rgb` or `#rrggbb`. |
| Trainings allowed before full membership | How many sessions someone may attend before they must join. |
| Enable booking functionality | Turns booking on the public site on or off. |
| Enable credits functionality | Turns credits on or off. |
| Credit/Token Expiry Days | How long bought credits last. |
| Backup recipient | Email that receives the daily backup, gzipped. Leave empty to not email backups. See [Backups](#8-backups). |
| Send test email to | Sends a test email straight away and shows the result or the error. Use it after any mail change. |
| Credit prices table (Quantity, Value) | Price per number of credits bought. |

**Content** (`/config/content`): bank (BACS) details shown to members, the
home page content, and the membership agreement (HTML shown above the "I agree
to the above" switch on the membership form; empty shows only the switch).

**LLM** (`/config/llm`): turn the chat and the LLM assistant on or off, and
the context text given to the LLM. The model and endpoint are set with
`LLM_STUDIO_URL` and `LLM_MODEL`.

**GoCardless** (`/config/config-gocardless` and `/config/gocardless`): turn
the bank feed on, set the GoCardless id and key, set the bank country
(two-letter code, default `GB`, which picks the list of banks offered), and
link the bank account.

## 7. Upgrading

The container runs `mix ecto.migrate` every time it starts, so an upgrade is:

1. Build and push the new image (see [section 2](#2-building-the-image)), or
   `docker pull` it on the host.
2. Take a backup copy of the database file first. Copy `DB_FILE` (and any
   `-wal`/`-shm` files next to it) somewhere safe, or copy the latest file
   from the backup folder.
3. Stop and remove the old container, and start a new one with the same
   `docker run` command and env file (see [section 3](#3-running-a-society)).
4. Watch the start-up in `docker exec -it oas tmux attach -t server`, and
   check `/health` returns `200`.

New releases may add environment variables. Compare your env file with
[.env.example](../.env.example) before restarting.

To go back, start the previous image tag against the database copy from
step 2. A newer database may not work with an older image once migrations
have run, so restore the copy rather than reusing the migrated file.

Rolling an upgrade out to several societies is **to be written** (see
[section 13](#13-rolling-out-to-every-society)).

## 8. Backups

**Schedule.** One backup a day at `BACKUP_TIME` (default 03:00) in the
society's time zone from Config. The next run is worked out again after each
run, so clock changes and a change of time zone are picked up the next day.
On a night when the time does not exist (clocks go forward) it runs just after
the gap; when it happens twice (clocks go back) it runs the first time.

**Where.** Each backup is a full copy of the database, written uncompressed
to `<DB_BACKUP_PATH>-<UTC timestamp>.db`. Mount that folder outside the
container.

**Check.** Each file is opened after writing and must contain the settings
row. If it does not, the error is logged and **the server stops** (it exits
so the problem is noticed). The Docker health check then fails. See
[troubleshooting](#the-server-stopped-after-a-backup).

**Retention.** After a backup that was written and checked, backup files
older than `BACKUP_KEEP_DAYS` (default 30) are deleted and each deletion is
logged. `BACKUP_KEEP_DAYS=0` keeps everything. Only files the backup itself
writes (named `<prefix>-<UTC timestamp>.db` in the backup folder) are ever
touched. Nothing is deleted if that day's backup failed, and the file just
written is never deleted. Copy any backup you want to keep for longer
somewhere else.

**Emailed copy.** If a backup recipient is set in Config, the same backup is
emailed to them gzipped, as `<society>-<timestamp>.db.gz`, with the subject
"<society name> backup". If the email fails, the error is logged and a warning
shows at the top of the admin site until a later backup email goes through.
The file on disk is written either way. Large databases may go over the mail
provider's attachment size limit.

**Off-site copies.** Copying backups to another machine or storage service
is **to be written** once the off-site target is decided.

**Restoring.**

1. Pick the backup file: one from the backup folder, or the emailed copy
   unzipped:
   ```
   gunzip <society>-<timestamp>.db.gz
   sqlite3 <society>-<timestamp>.db "SELECT * FROM config_config"   # optional check
   ```
2. Stop the container (`docker stop oas`).
3. Keep the current database aside (rename `DB_FILE` and any `-wal`/`-shm`
   files next to it), then copy the backup into place as `DB_FILE`, or point
   `DB_FILE` at the backup file.
4. Start the container. Migrations run on start, so an older backup is
   brought up to date. Check `/health` and log in.

Anything changed after the backup was taken is lost.

## 9. Health check

`GET /health` on the server host (e.g. `https://server.<domain>/health`)
returns JSON and is never cached:

```
{"status": "ok", "db": "ok", "last_backup_at": "2026-11-11T03:00:00.123Z", "last_backup_valid": true}
```

- `200` with `status: "ok"` when a trivial database query works.
- `503` with `status: "error"` when it fails; the reason is logged.
- `last_backup_at` and `last_backup_valid` describe the last backup since the
  server started (`null` before the first one). They do not affect the status.
- It shows no settings or secrets, so it is safe to point an uptime monitor
  at it.

The image has a Docker `HEALTHCHECK` that calls it inside the container every
30 seconds (5 s timeout, 120 s start period, 3 retries), so `docker ps` shows
`healthy` or `unhealthy`.

## 10. Rotating SECRET_KEY_BASE

`SECRET_KEY_BASE` signs the session cookie, the remember-me cookie and the
socket connection. Rotate it if it may have leaked, or if two societies were
ever run with the same one.

1. Generate a new one: `mix phx.gen.secret` (any machine with Elixir, or
   `docker exec -it oas mix phx.gen.secret`).
2. Put it in the society's env file as `SECRET_KEY_BASE`.
3. Recreate the container (`docker stop oas; docker rm oas; docker run ...`).
   A plain restart does not re-read the env file.

Effect: **every member is logged out** on every device, because their
cookies were signed with the old key, and must log in again. Passwords,
pending password reset links and confirmation links are not affected (those
tokens are stored hashed in the database, not signed with the key). Nothing
else needs changing.

## 11. Troubleshooting

Start with the start-up log line listing which settings came from the
environment, and `docker exec -it oas tmux attach -t server` for errors.

### The server will not start

It stops at start-up with a clear message when a variable has a bad value:
`PORT`, `SMTP_PORT` or `BACKUP_KEEP_DAYS` not a whole number, `BACKUP_TIME`
not `HH:MM`, `MAIL_ADAPTER` not `smtp`/`local`, `SMTP_TLS` not
`always`/`if_available`/`never`, or `MAIL_FROM_NAME` set without
`MAIL_FROM_ADDRESS`. Fix the env file and recreate the container.

### Emails are not arriving

1. Send a test email from the Config screen. It shows the mailer's error if
   sending fails.
2. If it says sent but nothing arrives, or password reset emails don't arrive
   while other emails do: check `MAIL_ADAPTER`. With `local`, or with it unset
   and the config file using the local adapter for one mailer, mail is kept in
   memory and never sent. Set `MAIL_ADAPTER=smtp`.
3. Authentication or TLS errors: check `SMTP_RELAY`, `SMTP_PORT`,
   `SMTP_USERNAME`, `SMTP_PASSWORD`, and use `SMTP_TLS=always` with port 587.
4. Mail lands in spam or is rejected: `MAIL_FROM_ADDRESS` must be on a domain
   the SMTP account is allowed to send from, with the provider's SPF and DKIM
   records in DNS.
5. A Gmail account stops sending after a number of emails a day; move to a
   transactional provider (see [Email](#email)).
6. Backup emails failing show as a warning at the top of the admin site. A
   very large database may be over the provider's attachment limit.

### CORS or socket errors in the browser

Symptoms: the admin or public site loads but data never appears, the browser
console shows a CORS error or a refused websocket, or the server log shows
`Could not check origin`.

- `ADMIN_URL` and `PUBLIC_URL` must match the address bar exactly: `https`
  vs `http`, `www.` or not, and any non-default port. They are compared on
  scheme, host and port.
- `PHX_HOST` must be the server's host name (host only is compared).
- Unset `ADMIN_URL`/`PUBLIC_URL` fall back to the config file's values,
  which in the prod image are Oxfordshire's. Check the start-up log.
- Open `https://server.<domain>/api/config.js` to see which URLs the apps
  were told to use.
- To confirm the origin check is the cause, start once with
  `ALLOW_ANY_ORIGIN=true`. If that fixes it, correct the URLs and remove it
  again.

### Login does not stick across subdomains

Members log in on the server host and then use the admin or public site. That
works only if the login cookie is visible to all three hosts.

- `DOMAIN` must be the shared parent domain with a leading dot, e.g.
  `.bristolacro.example`, and `server.`, `admin.` and `www.` must all be under
  it. Without `DOMAIN`, the v3 image uses `localhost` and logins don't carry
  over.
- After changing `DOMAIN`, old cookies on the previous domain can linger.
  Clear the site's cookies in the browser and log in again.
- Two societies on subdomains of one parent domain (e.g.
  `bristol.example.org` and `oxford.example.org`) must each use their own
  `DOMAIN` (`.bristol.example.org`), never the shared parent, and their own
  `SECRET_KEY_BASE`.
- Everyone logged out at once usually means `SECRET_KEY_BASE` changed (see
  [section 10](#10-rotating-secret_key_base)).

### The server stopped after a backup

A backup that fails its check stops the server on purpose. Look in the log
for `The backup file is not valid`. Common causes: the backup folder is not
mounted or is full, or the database itself is damaged. Free space or fix the
mount and start the container again; if the database is damaged, restore
from the last good backup (see [Backups](#8-backups)).

### `mix oas.provision` problems

- `Missing: --...`: all five options are required.
- `Nothing saved. Invalid settings: ...`: a time zone or currency was not
  accepted; use a name like `Europe/London` and a code like `GBP`.
- The link points at the wrong host: run it with `docker exec` in the running
  container so it sees the same `PHX_HOST`.
- The link has expired: run it again with `--new-link`.

## 12. Several societies on one machine

**To be written.** Whether each society runs on its own machine or several
run on one machine behind a shared reverse proxy (and how TLS is handled
there) is not decided yet. Today each container runs its own nginx on ports
80 and 443, so only one society fits per machine without extra set-up.

## 13. Rolling out to every society

**To be written.** A script to upgrade every society's container in turn
depends on the hosting decision above. Until then, upgrade each one by hand
as in [Upgrading](#7-upgrading).
