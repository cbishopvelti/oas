# OAS

This is the administration system for the Oxfordshire Acro Society.

### Features

#### Membership management
- **Authentication**: Secure user registration, login, and password recovery.
- **Roles & Permissions**: Support for Administrators, Reviewers, and Standard Members.
- **Profile Management**: Admins can manage members details.
- **Membership Status**: Tracking of active/inactive members and honorary statuses.
#### Event scheduling and attendance
- **Event Scheduling**: Administrators can schedule training sessions and jams.
- **Booking System**: Members can book upcoming sessions.
- **Attendance Tracking**: Track attendance for each event.
#### Financials
- **Open Banking Integration (Gocardless)**: Automatically pull transactions and link with members.
- **Financial Reporting**: Generate reports on income, expenses, and member balances.
- **Credits**: Management and tracking of members credits.
- **Credit Expiry**: Credits can be configured to expire after a certain period.
- **Credit Transfer**: Admins can transfer members credits between members.
- **Financial Analysis**: Generate reports and graphs of financial data.
#### Chat
- **Chat**: Provides members communication with an Admin or AI assistant.
- **AI tools**: Members can book in or query their credit balance through the chat interface.
#### Administration
- **Notifications** Members will recieve emails notifactions about their credit balance and booking vigilance.
- **Administration**: Admins can administer everything.
- **Backups**: Daily database snapshots with configurable offsite transfer.
- **Content Management**: Admins can manage content.

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

### Lisence

This project is **proprietary software**. All rights are reserved by Chris Bishop. 
Unauthorized copying, modification, or distribution of these files is strictly prohibited.
