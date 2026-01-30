# OAS

This is the administration system for the Oxfordshire Acro Society.

### Features

- Membership management
- Event scheduling and attendance
- Members credit management
- Financial tracking and reporting

### Installation

See the [docker_v2](docker_v2)

Initialize the database: ```mix ecto.create```
Run the migrations: ```mix ecto.migrate```
Start the server: ```iex -S mix phx.server```
Start the admin ui ```cd oas-web && npm run start && cd ../```
Start the frontend ui ```cd oas-web-public && npm run start && cd ../```

To setup an admin user, register through the UI then reset your password. In the dev environment, the reset email will be available at /dev/mailbox.
Open the sqlite database manually and set is_admin to true for that user.

### Deployment

see [README_v2_prod.md](README_v2_prod.md)
