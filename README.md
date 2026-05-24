# Server Manager App

A Flutter mobile application for managing online dedicated and bare metal servers.

## Features

- Dashboard with total servers, renewal alerts, monthly cost, and client count
- Add, edit, view, and delete server records
- Track IP address, provider, hosting location, specifications, OS, status, cost, purchase date, renewal date, and assigned client
- Search and filter by status, provider, client, IP address, or specs
- Remote MySQL/PHP API storage with local SQLite fallback/cache

## Run

```bash
flutter pub get
flutter run
```

## Remote database setup

1. Create a MySQL database on your hosting.
2. Import `api/schema.sql`.
3. Upload the `api/` folder to your hosting, for example:

```text
https://yourdomain.com/server-manager/api
```

4. Edit `api/config.php` with your database name, user, password, and `API_KEY`.
   Also change `WEB_PASSWORD`; this protects the browser dashboard.
5. Edit `lib/config/app_config.dart`:

```dart
static const remoteApiBaseUrl = 'https://yourdomain.com/server-manager/api';
static const remoteApiKey = 'same-key-as-api-config';
```

When `remoteApiBaseUrl` is empty, the app uses local SQLite only. When it is set, the app loads and saves server records through the hosting API.

## Web access

After uploading the `api/` folder and configuring `api/config.php`, open:

```text
https://yourdomain.com/server-manager/api/
```

That page is a browser dashboard for the same MySQL data. You can add, edit, and delete server records there, and the mobile app will load the same records from the API.

## Main files

- `lib/main.dart` - App bootstrap and theme
- `lib/models/server.dart` - Server data model
- `lib/services/server_store.dart` - CRUD store with remote API and local cache
- `lib/services/server_api.dart` - Remote API client
- `lib/services/server_database.dart` - Local SQLite cache
- `lib/screens/home_screen.dart` - Dashboard and server list
- `lib/screens/server_detail_screen.dart` - Server details
- `lib/screens/server_form_screen.dart` - Add/edit form
- `assets/icons/server_manager_icon.svg` - Source app/web icon artwork
