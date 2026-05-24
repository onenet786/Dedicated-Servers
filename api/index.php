<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

session_start();

$statuses = ['active', 'dueSoon', 'overdue', 'suspended', 'retired'];
$statusLabels = [
    'active' => 'Active',
    'dueSoon' => 'Due Soon',
    'overdue' => 'Overdue',
    'suspended' => 'Suspended',
    'retired' => 'Retired',
];

try {
    handle_auth();

    if (!is_logged_in()) {
        render_login();
        exit;
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        handle_form_submit($statuses);
        header('Location: index.php');
        exit;
    }

    $editingServer = null;
    if (isset($_GET['edit'])) {
        $editingServer = find_server((string) $_GET['edit']);
    }

    $servers = fetch_servers();
} catch (Throwable $exception) {
    http_response_code(500);
    $error = $exception->getMessage();
    $servers = [];
    $editingServer = null;
}

function handle_auth(): void
{
    if (($_POST['action'] ?? '') === 'login') {
        $password = (string) ($_POST['password'] ?? '');
        if (hash_equals(WEB_PASSWORD, $password)) {
            $_SESSION['server_manager_logged_in'] = true;
        } else {
            $_SESSION['server_manager_login_error'] = 'Invalid password';
        }
        header('Location: index.php');
        exit;
    }

    if (($_GET['logout'] ?? '') === '1') {
        $_SESSION = [];
        session_destroy();
        header('Location: index.php');
        exit;
    }
}

function is_logged_in(): bool
{
    return ($_SESSION['server_manager_logged_in'] ?? false) === true;
}

function render_login(): void
{
    $error = $_SESSION['server_manager_login_error'] ?? '';
    unset($_SESSION['server_manager_login_error']);
    ?>
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Server Manager Login</title>
      <style>
        body {
          align-items: center;
          background: #f7f9fb;
          color: #111827;
          display: flex;
          font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          justify-content: center;
          margin: 0;
          min-height: 100vh;
          padding: 20px;
        }

        form {
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
          max-width: 390px;
          padding: 20px;
          width: 100%;
        }

        h1 {
          align-items: center;
          display: flex;
          font-size: 22px;
          gap: 10px;
          margin: 0 0 16px;
        }

        h1 img {
          border-radius: 8px;
          height: 34px;
          width: 34px;
        }

        label {
          color: #4b5563;
          display: grid;
          font-size: 12px;
          font-weight: 800;
          gap: 6px;
        }

        input {
          border: 1px solid #e5e7eb;
          border-radius: 6px;
          font: inherit;
          min-height: 42px;
          padding: 10px 11px;
        }

        button {
          background: #111827;
          border: 0;
          border-radius: 6px;
          color: white;
          cursor: pointer;
          font: inherit;
          font-weight: 800;
          margin-top: 14px;
          min-height: 42px;
          width: 100%;
        }

        .error {
          color: #991b1b;
          font-size: 14px;
          margin-bottom: 12px;
        }
      </style>
    </head>
    <body>
      <form method="post">
        <h1><img src="assets/icon-192.png" alt=""> Server Manager</h1>
        <?php if ($error): ?>
          <div class="error"><?= h($error) ?></div>
        <?php endif; ?>
        <input type="hidden" name="action" value="login">
        <label>Password
          <input name="password" type="password" required autofocus>
        </label>
        <button type="submit">Sign In</button>
      </form>
    </body>
    </html>
    <?php
}

function handle_form_submit(array $statuses): void
{
    $action = $_POST['action'] ?? '';

    if ($action === 'delete') {
        delete_server((string) ($_POST['id'] ?? ''));
        return;
    }

    if ($action !== 'save') {
        return;
    }

    $status = (string) ($_POST['status'] ?? 'active');
    if (!in_array($status, $statuses, true)) {
        $status = 'active';
    }

    $server = [
        'id' => trim((string) ($_POST['id'] ?? '')) ?: bin2hex(random_bytes(16)),
        'name' => trim((string) ($_POST['name'] ?? '')),
        'ip_address' => trim((string) ($_POST['ip_address'] ?? '')),
        'provider' => trim((string) ($_POST['provider'] ?? '')),
        'location' => trim((string) ($_POST['location'] ?? '')),
        'specification' => trim((string) ($_POST['specification'] ?? '')),
        'operating_system' => trim((string) ($_POST['operating_system'] ?? '')),
        'login_user' => trim((string) ($_POST['login_user'] ?? '')),
        'monthly_cost' => (float) ($_POST['monthly_cost'] ?? 0),
        'purchase_date' => date_to_iso((string) ($_POST['purchase_date'] ?? '')),
        'renewal_date' => date_to_iso((string) ($_POST['renewal_date'] ?? '')),
        'assigned_client' => trim((string) ($_POST['assigned_client'] ?? '')),
        'status' => $status,
        'notes' => trim((string) ($_POST['notes'] ?? '')),
    ];

    save_server($server);
}

function fetch_servers(): array
{
    $statement = db()->query('SELECT * FROM servers ORDER BY renewal_date ASC');
    return $statement->fetchAll();
}

function find_server(string $id): ?array
{
    $statement = db()->prepare('SELECT * FROM servers WHERE id = :id');
    $statement->execute([':id' => $id]);
    $server = $statement->fetch();
    return $server ?: null;
}

function save_server(array $server): void
{
    $sql = '
        INSERT INTO servers (
            id,
            name,
            ip_address,
            provider,
            location,
            specification,
            operating_system,
            login_user,
            monthly_cost,
            purchase_date,
            renewal_date,
            assigned_client,
            status,
            notes
        ) VALUES (
            :id,
            :name,
            :ip_address,
            :provider,
            :location,
            :specification,
            :operating_system,
            :login_user,
            :monthly_cost,
            :purchase_date,
            :renewal_date,
            :assigned_client,
            :status,
            :notes
        )
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            ip_address = VALUES(ip_address),
            provider = VALUES(provider),
            location = VALUES(location),
            specification = VALUES(specification),
            operating_system = VALUES(operating_system),
            login_user = VALUES(login_user),
            monthly_cost = VALUES(monthly_cost),
            purchase_date = VALUES(purchase_date),
            renewal_date = VALUES(renewal_date),
            assigned_client = VALUES(assigned_client),
            status = VALUES(status),
            notes = VALUES(notes)
    ';

    db()->prepare($sql)->execute([
        ':id' => $server['id'],
        ':name' => $server['name'],
        ':ip_address' => $server['ip_address'],
        ':provider' => $server['provider'],
        ':location' => $server['location'],
        ':specification' => $server['specification'],
        ':operating_system' => $server['operating_system'],
        ':login_user' => $server['login_user'],
        ':monthly_cost' => $server['monthly_cost'],
        ':purchase_date' => $server['purchase_date'],
        ':renewal_date' => $server['renewal_date'],
        ':assigned_client' => $server['assigned_client'],
        ':status' => $server['status'],
        ':notes' => $server['notes'],
    ]);
}

function delete_server(string $id): void
{
    if ($id === '') {
        return;
    }

    $statement = db()->prepare('DELETE FROM servers WHERE id = :id');
    $statement->execute([':id' => $id]);
}

function date_to_iso(string $date): string
{
    if ($date === '') {
        return date('c');
    }

    return (new DateTimeImmutable($date))->format(DateTimeInterface::ATOM);
}

function date_for_input(?string $date): string
{
    if (!$date) {
        return date('Y-m-d');
    }

    return (new DateTimeImmutable($date))->format('Y-m-d');
}

function days_until(?string $date): int
{
    if (!$date) {
        return 0;
    }

    $today = new DateTimeImmutable('today');
    $renewal = (new DateTimeImmutable($date))->setTime(0, 0);
    return (int) $today->diff($renewal)->format('%r%a');
}

function h(?string $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

function selected(string $actual, string $expected): string
{
    return $actual === $expected ? 'selected' : '';
}

$form = $editingServer ?? [
    'id' => '',
    'name' => '',
    'ip_address' => '',
    'provider' => '',
    'location' => '',
    'specification' => '',
    'operating_system' => '',
    'login_user' => 'root',
    'monthly_cost' => '',
    'purchase_date' => date('c'),
    'renewal_date' => (new DateTimeImmutable('+30 days'))->format(DateTimeInterface::ATOM),
    'assigned_client' => '',
    'status' => 'active',
    'notes' => '',
];
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#2563eb">
  <title>Server Manager</title>
  <link rel="icon" type="image/png" href="assets/favicon.png">
  <link rel="apple-touch-icon" href="assets/icon-192.png">
  <link rel="manifest" href="site.webmanifest">
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f9fb;
      --panel: #ffffff;
      --ink: #111827;
      --muted: #4b5563;
      --subtle: #9ca3af;
      --line: #e5e7eb;
      --blue: #111827;
      --teal: #0f766e;
      --green-bg: #dcfce7;
      --green: #166534;
      --amber-bg: #fef3c7;
      --amber: #92400e;
      --red-bg: #fee2e2;
      --red: #991b1b;
      --indigo-bg: #e0e7ff;
      --indigo: #3730a3;
      --gray-bg: #e5e7eb;
      --gray: #374151;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .topbar {
      background: var(--panel);
      border-bottom: 1px solid var(--line);
      position: sticky;
      top: 0;
      z-index: 5;
    }

    .topbar-inner {
      align-items: center;
      display: flex;
      gap: 14px;
      justify-content: space-between;
      margin: 0 auto;
      max-width: 1180px;
      padding: 16px 20px;
    }

    .brand {
      align-items: center;
      display: flex;
      gap: 11px;
      min-width: 0;
    }

    .brand img {
      border-radius: 8px;
      height: 36px;
      width: 36px;
    }

    h1 {
      font-size: 20px;
      margin: 0;
    }

    .count {
      color: var(--muted);
      font-size: 14px;
      font-weight: 700;
    }

    .topbar-actions {
      align-items: center;
      display: flex;
      gap: 12px;
    }

    main {
      display: grid;
      gap: 18px;
      grid-template-columns: minmax(300px, 390px) minmax(0, 1fr);
      margin: 0 auto;
      max-width: 1180px;
      padding: 20px;
    }

    section {
      min-width: 0;
    }

    h2 {
      font-size: 16px;
      margin: 0 0 12px;
    }

    .form-panel,
    .table-panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: 0 1px 2px rgba(17, 24, 39, 0.04);
      padding: 16px;
    }

    .form-grid {
      display: grid;
      gap: 12px;
    }

    label {
      color: var(--muted);
      display: grid;
      font-size: 12px;
      font-weight: 800;
      gap: 5px;
    }

    input,
    select,
    textarea {
      border: 1px solid var(--line);
      border-radius: 6px;
      color: var(--ink);
      font: inherit;
      min-height: 42px;
      padding: 10px 11px;
      width: 100%;
    }

    input:focus,
    select:focus,
    textarea:focus {
      border-color: var(--teal);
      box-shadow: 0 0 0 3px rgba(15, 118, 110, 0.12);
      outline: 0;
    }

    textarea {
      min-height: 92px;
      resize: vertical;
    }

    .split {
      display: grid;
      gap: 10px;
      grid-template-columns: 1fr 1fr;
    }

    .actions {
      display: flex;
      gap: 10px;
      margin-top: 14px;
    }

    button,
    .button {
      align-items: center;
      background: var(--blue);
      border: 0;
      border-radius: 6px;
      color: white;
      cursor: pointer;
      display: inline-flex;
      font: inherit;
      font-weight: 800;
      justify-content: center;
      min-height: 42px;
      padding: 0 14px;
      text-decoration: none;
    }

    .button.secondary {
      background: #f3f4f6;
      color: #374151;
    }

    .button.danger,
    button.danger {
      background: #dc2626;
    }

    .table-wrap {
      overflow-x: auto;
    }

    table {
      border-collapse: collapse;
      min-width: 820px;
      width: 100%;
    }

    th,
    td {
      border-bottom: 1px solid var(--line);
      padding: 12px 10px;
      text-align: left;
      vertical-align: top;
    }

    th {
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
    }

    tbody tr:hover {
      background: #f9fafb;
    }

    td strong {
      display: block;
      margin-bottom: 3px;
    }

    .muted {
      color: var(--muted);
      font-size: 13px;
    }

    .chip {
      border-radius: 999px;
      display: inline-flex;
      font-size: 12px;
      font-weight: 800;
      padding: 5px 9px;
      white-space: nowrap;
    }

    .active { background: var(--green-bg); color: var(--green); }
    .dueSoon { background: var(--amber-bg); color: var(--amber); }
    .overdue { background: var(--red-bg); color: var(--red); }
    .suspended { background: var(--indigo-bg); color: var(--indigo); }
    .retired { background: var(--gray-bg); color: var(--gray); }

    .row-actions {
      display: flex;
      gap: 8px;
    }

    .inline-form {
      display: inline;
    }

    .empty,
    .error {
      border: 1px dashed var(--line);
      border-radius: 8px;
      color: var(--muted);
      padding: 22px;
      text-align: center;
    }

    .error {
      border-color: #fecaca;
      color: var(--red);
      margin: 20px auto 0;
      max-width: 1180px;
    }

    @media (max-width: 860px) {
      main {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <header class="topbar">
    <div class="topbar-inner">
      <div class="brand">
        <img src="assets/icon-192.png" alt="">
        <h1>Server Manager</h1>
      </div>
      <div class="topbar-actions">
        <span class="count"><?= count($servers) ?> servers</span>
        <a class="button secondary" href="index.php?logout=1">Logout</a>
      </div>
    </div>
  </header>

  <?php if (isset($error)): ?>
    <div class="error"><?= h($error) ?></div>
  <?php endif; ?>

  <main>
    <section class="form-panel">
      <h2><?= $editingServer ? 'Edit Server' : 'Add Server' ?></h2>
      <form method="post" class="form-grid">
        <input type="hidden" name="action" value="save">
        <input type="hidden" name="id" value="<?= h($form['id']) ?>">

        <label>Server Name
          <input name="name" value="<?= h($form['name']) ?>" required>
        </label>

        <label>IP Address
          <input name="ip_address" value="<?= h($form['ip_address']) ?>" required>
        </label>

        <div class="split">
          <label>Provider
            <input name="provider" value="<?= h($form['provider']) ?>" required>
          </label>
          <label>Location
            <input name="location" value="<?= h($form['location']) ?>" required>
          </label>
        </div>

        <label>Specification
          <textarea name="specification" required><?= h($form['specification']) ?></textarea>
        </label>

        <div class="split">
          <label>Operating System
            <input name="operating_system" value="<?= h($form['operating_system']) ?>" required>
          </label>
          <label>Login User
            <input name="login_user" value="<?= h($form['login_user']) ?>" required>
          </label>
        </div>

        <div class="split">
          <label>Monthly Cost
            <input name="monthly_cost" type="number" min="0" step="0.01" value="<?= h((string) $form['monthly_cost']) ?>" required>
          </label>
          <label>Status
            <select name="status">
              <?php foreach ($statuses as $status): ?>
                <option value="<?= h($status) ?>" <?= selected((string) $form['status'], $status) ?>>
                  <?= h($statusLabels[$status]) ?>
                </option>
              <?php endforeach; ?>
            </select>
          </label>
        </div>

        <label>Assigned Client
          <input name="assigned_client" value="<?= h($form['assigned_client']) ?>" required>
        </label>

        <div class="split">
          <label>Purchase Date
            <input name="purchase_date" type="date" value="<?= h(date_for_input($form['purchase_date'])) ?>" required>
          </label>
          <label>Renewal Date
            <input name="renewal_date" type="date" value="<?= h(date_for_input($form['renewal_date'])) ?>" required>
          </label>
        </div>

        <label>Notes
          <textarea name="notes"><?= h($form['notes']) ?></textarea>
        </label>

        <div class="actions">
          <button type="submit">Save</button>
          <?php if ($editingServer): ?>
            <a class="button secondary" href="index.php">Cancel</a>
          <?php endif; ?>
        </div>
      </form>
    </section>

    <section class="table-panel">
      <h2>Servers</h2>
      <?php if (!$servers): ?>
        <div class="empty">No servers saved yet.</div>
      <?php else: ?>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Server</th>
                <th>Client</th>
                <th>Provider</th>
                <th>Status</th>
                <th>Renewal</th>
                <th>Monthly</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <?php foreach ($servers as $server): ?>
                <?php $days = days_until($server['renewal_date']); ?>
                <tr>
                  <td>
                    <strong><?= h($server['name']) ?></strong>
                    <span class="muted"><?= h($server['ip_address']) ?></span>
                  </td>
                  <td><?= h($server['assigned_client']) ?></td>
                  <td>
                    <?= h($server['provider']) ?><br>
                    <span class="muted"><?= h($server['location']) ?></span>
                  </td>
                  <td>
                    <span class="chip <?= h($server['status']) ?>">
                      <?= h($statusLabels[$server['status']] ?? $server['status']) ?>
                    </span>
                  </td>
                  <td>
                    <?= h(date_for_input($server['renewal_date'])) ?><br>
                    <span class="muted"><?= $days < 0 ? abs($days) . ' days overdue' : $days . ' days left' ?></span>
                  </td>
                  <td>$<?= number_format((float) $server['monthly_cost'], 2) ?></td>
                  <td>
                    <div class="row-actions">
                      <a class="button secondary" href="index.php?edit=<?= urlencode($server['id']) ?>">Edit</a>
                      <form method="post" class="inline-form" onsubmit="return confirm('Delete this server?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="<?= h($server['id']) ?>">
                        <button class="danger" type="submit">Delete</button>
                      </form>
                    </div>
                  </td>
                </tr>
              <?php endforeach; ?>
            </tbody>
          </table>
        </div>
      <?php endif; ?>
    </section>
  </main>
</body>
</html>
