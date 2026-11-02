# OAS

This is the administration system for the Oxfordshire Acro Society. It is the code that runs [https://www.oxfordshireacrosociety.co.uk/](https://www.oxfordshireacrosociety.co.uk/).

### Features

#### Membership management
- **Authentication**: Secure user registration, login, and password recovery.
- **Roles & Permissions**: Support for Administrators, Reviewers, and Standard Members.
- **Profile Management**: Admins can manage members details.
- **Membership Status**: Tracking of active/inactive members and honorary statuses.
#### Event scheduling and attendance
- **Event Scheduling**: Administrators can schedule training sessions and jams.
- **Booking System**: Members can book upcoming sessions.
- **book in via nfc or qr code**: Attendees can book in via nfc tag or qr code.
- **Attendance Tracking**: Track attendance for each event.
- **Analysis**: Reports and graphs of attendance data.
#### Financials
- **Open Banking Integration (Gocardless)**: Automatically pull transactions and link with members.
- **Financial Reporting**: Generate reports on income, expenses, and member balances.
- **Credits**: Management and tracking of members credits.
- **Credit Expiry**: Credits can be configured to expire after a certain period.
- **Credit Transfer**: Admins can transfer users credits to other users.
- **Financial Analysis**: Generate reports and graphs of financial data.
#### Chat
- **Chat**: Provides members communication with an Admin or AI assistant.
- **AI tools**: Members can book in or query their credit balance through the chat interface.
#### Administration
- **Notifications** Members will recieve emails notifactions about their credit balance and booking vigilance.
- **Administration**: Admins can administer everything.
- **Reviewers**: Reviewers can monitor data.
- **Backups**: Daily database snapshots with configurable offsite transfer.
- **Content Management**: Admins can manage content.

### Installation

See the [docker_v2](docker_v2)

Initialize the database: ```mix ecto.create```
Run the migrations: ```mix ecto.migrate```
Start the server: ```iex -S mix phx.server```
Start the admin ui ```cd oas-web && npm run start && cd ../```
Start the public ui ```cd oas-web-public && npm run start && cd ../```

To setup an admin user, register through the UI then reset your password. In the dev environment, the reset email will be available at /dev/mailbox.
Open the sqlite database manually and set is_admin to true for that user.

### Deployment

see [README_v2_prod.md](README_v2_prod.md)

### Secrets

Secrets are never kept in the config files. `config/runtime.exs` reads them from environment variables at boot.

| Variable | Required in | Purpose |
| --- | --- | --- |
| `SECRET_KEY_BASE` | prod-like envs | Signs and encrypts cookies and socket tokens. Generate with `mix phx.gen.secret`. |
| `LIVE_VIEW_SIGNING_SALT` | prod-like envs | LiveView signing salt. Generate with `mix phx.gen.secret 32`. |
| `SMTP_PASSWORD` | prod-like envs | Gmail app password for `Oas.Mailer` and `Oas.TokenMailer`. |
| `SMTP_USERNAME` | optional | Overrides the SMTP username set in the env config file. |

"Prod-like" means every `MIX_ENV` except `dev`, `dev_mac` and `test` (so `gcloud`, `gcloud_dev`, `v2_prod`, `v3_staging`, ...). If a required variable is missing there, boot stops with an error naming it. In `dev`, `dev_mac` and `test` the variables are optional and override the local defaults.

On the server keep them in an env file outside the repo, readable only by root, and pass it to `docker run` with `--env-file`:

```
# /root/oas.env  (chmod 600)
SECRET_KEY_BASE=...
LIVE_VIEW_SIGNING_SALT=...
SMTP_PASSWORD=...
```

The gitignored `config/v2_prod.exs` and `config/v3_staging.exs` should no longer set `secret_key_base`, `live_view: [signing_salt: ...]` or SMTP `password`. Delete those lines and put the values in the env file instead. If they stay, the env vars still win, because `runtime.exs` is applied last.

### Lisence

This project is **proprietary software**. All rights are reserved by Christopher Bishop. 
Unauthorized copying, modification, or distribution of these files is strictly prohibited.
