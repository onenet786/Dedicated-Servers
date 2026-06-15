<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

session_start();

defined('WHATSAPP_WEBHOOK_URL') || define('WHATSAPP_WEBHOOK_URL', 'http://192.168.85.130:5678/webhook/whatsapp-invoice');
defined('WHATSAPP_SENDER') || define('WHATSAPP_SENDER', 'reports4');

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
    }

    $servers = fetch_servers();
    $page = (string) ($_GET['page'] ?? 'list');

    render_layout(function () use ($page, $servers, $statuses, $statusLabels): void {
        if ($page === 'form') {
            render_form_view($servers, $statuses, $statusLabels);
            return;
        }

        if ($page === 'detail') {
            render_detail_view($servers, $statusLabels);
            return;
        }

        if ($page === 'reports') {
            render_reports_view($servers, $statusLabels);
            return;
        }

        render_list_view($servers, $statusLabels);
    }, $servers);
} catch (Throwable $exception) {
    http_response_code(500);
    render_layout(function () use ($exception): void {
        echo '<div class="error">' . h($exception->getMessage()) . '</div>';
    }, []);
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

function handle_form_submit(array $statuses): never
{
    $action = $_POST['action'] ?? '';
    $id = (string) ($_POST['id'] ?? '');

    if ($action === 'delete') {
        delete_server($id);
        header('Location: index.php');
        exit;
    }

    if ($action === 'send_whatsapp') {
        $server = find_server(fetch_servers(), $id);
        if (!$server) {
            set_flash('error', 'Server not found.');
        } else {
            try {
                send_whatsapp_message($server);
                set_flash('success', 'WhatsApp message sent.');
            } catch (Throwable $exception) {
                set_flash('error', $exception->getMessage());
            }
        }
        header('Location: index.php?page=detail&id=' . urlencode($id));
        exit;
    }

    if ($action !== 'save') {
        header('Location: index.php');
        exit;
    }

    $parentId = trim((string) ($_POST['parent_id'] ?? '')) ?: null;
    $status = (string) ($_POST['status'] ?? 'active');
    if (!in_array($status, $statuses, true)) {
        $status = 'active';
    }

    $savedId = trim($id) ?: bin2hex(random_bytes(16));
    $isVm = $parentId !== null;

    $server = [
        'id' => $savedId,
        'parent_id' => $parentId,
        'name' => trim((string) ($_POST['name'] ?? '')),
        'ip_address' => trim((string) ($_POST['ip_address'] ?? '')),
        'provider' => trim((string) ($_POST['provider'] ?? '')),
        'location' => trim((string) ($_POST['location'] ?? '')),
        'specification' => trim((string) ($_POST['specification'] ?? '')),
        'operating_system' => trim((string) ($_POST['operating_system'] ?? '')),
        'login_user' => trim((string) ($_POST['login_user'] ?? '')),
        'monthly_cost' => $isVm ? 0 : (float) ($_POST['monthly_cost'] ?? 0),
        'purchase_date' => date_to_iso((string) ($_POST['purchase_date'] ?? '')),
        'renewal_date' => date_to_iso((string) ($_POST['renewal_date'] ?? '')),
        'assigned_client' => trim((string) ($_POST['assigned_client'] ?? '')),
        'client_phone' => trim((string) ($_POST['client_phone'] ?? '')),
        'status' => $status,
        'notes' => trim((string) ($_POST['notes'] ?? '')),
        'vm_cpu_cores' => trim((string) ($_POST['vm_cpu_cores'] ?? '')) ?: null,
        'vm_memory_gb' => trim((string) ($_POST['vm_memory_gb'] ?? '')) ?: null,
        'vm_disk_gb' => trim((string) ($_POST['vm_disk_gb'] ?? '')) ?: null,
        'vm_storage' => trim((string) ($_POST['vm_storage'] ?? '')) ?: null,
        'vm_role' => trim((string) ($_POST['vm_role'] ?? '')) ?: null,
    ];

    if ($isVm && $server['specification'] === '') {
        $server['specification'] = vm_spec_text($server);
    }

    save_server($server);
    header('Location: index.php?page=detail&id=' . urlencode($parentId ?? $savedId));
    exit;
}

function fetch_servers(): array
{
    $statement = db()->query('SELECT * FROM servers ORDER BY COALESCE(parent_id, id), parent_id IS NOT NULL, renewal_date ASC');
    return $statement->fetchAll();
}

function find_server(array $servers, string $id): ?array
{
    foreach ($servers as $server) {
        if ((string) $server['id'] === $id) {
            return $server;
        }
    }
    return null;
}

function root_servers(array $servers): array
{
    return array_values(array_filter($servers, fn(array $server): bool => empty($server['parent_id'])));
}

function child_servers(array $servers, string $parentId): array
{
    return array_values(array_filter($servers, fn(array $server): bool => (string) ($server['parent_id'] ?? '') === $parentId));
}

function save_server(array $server): void
{
    $sql = '
        INSERT INTO servers (
            id, parent_id, name, ip_address, provider, location, specification,
            operating_system, login_user, monthly_cost, purchase_date, renewal_date,
            assigned_client, client_phone, status, notes, vm_cpu_cores, vm_memory_gb, vm_disk_gb,
            vm_storage, vm_role
        ) VALUES (
            :id, :parent_id, :name, :ip_address, :provider, :location, :specification,
            :operating_system, :login_user, :monthly_cost, :purchase_date, :renewal_date,
            :assigned_client, :client_phone, :status, :notes, :vm_cpu_cores, :vm_memory_gb, :vm_disk_gb,
            :vm_storage, :vm_role
        )
        ON DUPLICATE KEY UPDATE
            parent_id = VALUES(parent_id),
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
            client_phone = VALUES(client_phone),
            status = VALUES(status),
            notes = VALUES(notes),
            vm_cpu_cores = VALUES(vm_cpu_cores),
            vm_memory_gb = VALUES(vm_memory_gb),
            vm_disk_gb = VALUES(vm_disk_gb),
            vm_storage = VALUES(vm_storage),
            vm_role = VALUES(vm_role)
    ';

    db()->prepare($sql)->execute([
        ':id' => $server['id'],
        ':parent_id' => $server['parent_id'],
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
        ':client_phone' => $server['client_phone'] ?? '',
        ':status' => $server['status'],
        ':notes' => $server['notes'],
        ':vm_cpu_cores' => $server['vm_cpu_cores'],
        ':vm_memory_gb' => $server['vm_memory_gb'],
        ':vm_disk_gb' => $server['vm_disk_gb'],
        ':vm_storage' => $server['vm_storage'],
        ':vm_role' => $server['vm_role'],
    ]);
}

function delete_server(string $id): void
{
    if ($id === '') {
        return;
    }

    $statement = db()->prepare('DELETE FROM servers WHERE id = :id OR parent_id = :id');
    $statement->execute([':id' => $id]);
}

function render_layout(callable $content, array $servers): void
{
    $roots = root_servers($servers);
    $vmCount = count($servers) - count($roots);
    $dueNotifications = due_notification_payloads($roots);
    ?>
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="theme-color" content="#111827">
      <title>Server Manager</title>
      <link rel="icon" type="image/png" href="assets/favicon.png">
      <link rel="apple-touch-icon" href="assets/icon-192.png">
      <link rel="manifest" href="site.webmanifest">
      <style>
        :root {
          --ink: #111827;
          --muted: #4b5563;
          --line: #e5e7eb;
          --panel: #ffffff;
          --blue: #2563eb;
          --teal: #0f766e;
          --violet: #7c3aed;
          --green: #059669;
          --amber: #d97706;
          --red: #dc2626;
          --soft-blue: #e0f2fe;
          --soft-violet: #f5f3ff;
          --soft-amber: #fffbeb;
        }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          color: var(--ink);
          font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          background: linear-gradient(135deg, var(--soft-blue), var(--soft-violet), var(--soft-amber));
          min-height: 100vh;
        }
        .topbar { background: #111827; color: white; position: sticky; top: 0; z-index: 5; }
        .topbar-inner { max-width: 1180px; margin: 0 auto; padding: 14px 18px; display: flex; justify-content: space-between; align-items: center; gap: 12px; }
        .brand { display: flex; align-items: center; gap: 10px; min-width: 0; }
        .brand img { width: 36px; height: 36px; border-radius: 10px; }
        .brand strong { font-size: 18px; }
        .top-actions { display: flex; align-items: center; gap: 10px; }
        .shell { max-width: 1180px; margin: 0 auto; padding: 18px; }
        .hero {
          background: linear-gradient(135deg, #111827, #0f766e, #2563eb);
          color: white;
          border-radius: 16px;
          padding: 20px;
          box-shadow: 0 18px 38px rgba(37, 99, 235, .22);
          margin-bottom: 18px;
        }
        .hero h1 { margin: 5px 0 16px; font-size: 26px; }
        .eyebrow { color: #bfdbfe; font-size: 12px; font-weight: 800; }
        .metrics { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
        .metric { background: rgba(255,255,255,.13); border: 1px solid rgba(255,255,255,.18); border-radius: 12px; padding: 12px; }
        .metric strong { display: block; font-size: 22px; margin-bottom: 3px; }
        .metric span { color: #dbeafe; font-size: 12px; }
        .panel { background: rgba(255,255,255,.94); border: 1px solid rgba(224,231,255,.9); border-radius: 12px; box-shadow: 0 8px 24px rgba(17,24,39,.08); padding: 16px; margin-bottom: 14px; }
        .panel-title { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 12px; }
        .panel-title h2 { margin: 0; font-size: 17px; }
        .server-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
        .server-card { display: block; color: inherit; text-decoration: none; background: white; border: 1px solid #e0e7ff; border-left: 5px solid var(--teal); border-radius: 12px; padding: 14px; }
        .server-card:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(17,24,39,.08); }
        .server-head { display: flex; justify-content: space-between; gap: 10px; align-items: flex-start; margin-bottom: 10px; }
        .server-name { font-weight: 850; }
        .muted { color: var(--muted); font-size: 13px; }
        .chip { border-radius: 6px; display: inline-flex; font-size: 12px; font-weight: 800; padding: 5px 9px; white-space: nowrap; border: 1px solid transparent; }
        .active { background: #ecfdf5; color: #059669; border-color: rgba(5,150,105,.18); }
        .dueSoon { background: #fffbeb; color: #d97706; border-color: rgba(217,119,6,.18); }
        .overdue { background: #fef2f2; color: #dc2626; border-color: rgba(220,38,38,.18); }
        .suspended { background: #f5f3ff; color: #7c3aed; border-color: rgba(124,58,237,.18); }
        .retired { background: #f1f5f9; color: #64748b; border-color: rgba(100,116,139,.18); }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
        .info { background: #f8fafc; border-radius: 10px; border: 1px solid var(--line); padding: 12px; }
        .info span { display: block; color: var(--muted); font-size: 12px; font-weight: 800; margin-bottom: 4px; }
        .button, button { display: inline-flex; align-items: center; justify-content: center; min-height: 40px; padding: 0 13px; border-radius: 8px; border: 0; background: #111827; color: white; text-decoration: none; font: inherit; font-weight: 800; cursor: pointer; }
        .button.secondary { background: #f3f4f6; color: #374151; }
        .button.teal { background: var(--teal); }
        .button.danger, button.danger { background: var(--red); }
        .button.notify { background: #7c3aed; }
        .actions { display: flex; gap: 8px; flex-wrap: wrap; }
        form.grid { display: grid; gap: 12px; }
        label { display: grid; gap: 5px; color: var(--muted); font-size: 12px; font-weight: 800; }
        input, select, textarea { width: 100%; min-height: 42px; border: 1px solid var(--line); border-radius: 8px; padding: 10px 11px; font: inherit; color: var(--ink); background: white; }
        textarea { min-height: 92px; resize: vertical; }
        input:focus, select:focus, textarea:focus { outline: 0; border-color: var(--teal); box-shadow: 0 0 0 3px rgba(15,118,110,.12); }
        .split { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .empty, .error { color: var(--muted); border: 1px dashed var(--line); border-radius: 10px; padding: 18px; text-align: center; }
        .flash { border-radius: 10px; font-weight: 800; margin-bottom: 14px; padding: 13px 15px; }
        .flash.success { background: #ecfdf5; color: #047857; border: 1px solid rgba(5,150,105,.2); }
        .flash.error { background: #fef2f2; color: #b91c1c; border: 1px solid rgba(220,38,38,.2); }
        .vm-card { border-left-color: var(--violet); }
        .report-stack { display: grid; gap: 14px; }
        .report-metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-bottom: 12px; }
        .report-metric { background: #f8fafc; border: 1px solid var(--line); border-radius: 10px; padding: 12px; }
        .report-metric span { color: var(--muted); display: block; font-size: 12px; font-weight: 800; margin-top: 4px; }
        .report-metric strong { font-size: 22px; }
        .report-row { margin-bottom: 11px; }
        .report-row-head { align-items: center; display: flex; gap: 10px; justify-content: space-between; margin-bottom: 6px; }
        .report-row-head strong { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .report-row-head span { color: var(--muted); font-size: 12px; font-weight: 800; white-space: nowrap; }
        .bar { background: #e5e7eb; border-radius: 999px; height: 8px; overflow: hidden; }
        .bar i { background: linear-gradient(90deg, var(--teal), var(--blue)); display: block; height: 100%; }
        .report-line { align-items: center; background: #f8fafc; border: 1px solid var(--line); border-radius: 10px; display: flex; gap: 10px; justify-content: space-between; margin-bottom: 10px; padding: 12px; }
        .report-line strong { display: block; }
        .report-line span { color: var(--muted); font-size: 13px; }
        .report-line b { color: var(--teal); white-space: nowrap; }
        @media (max-width: 700px) {
          .metrics, .split { grid-template-columns: 1fr; }
          .topbar-inner { align-items: flex-start; flex-direction: column; }
          .top-actions { flex-wrap: wrap; }
        }
      </style>
    </head>
    <body>
      <header class="topbar">
        <div class="topbar-inner">
          <a class="brand" href="index.php" style="color:white;text-decoration:none;">
            <img src="assets/icon-192.png" alt="">
            <strong>Server Manager</strong>
          </a>
          <div class="top-actions">
            <a class="button secondary" href="index.php?page=form">Add Server</a>
            <a class="button secondary" href="index.php?page=reports">Reports</a>
            <button class="button notify" type="button" onclick="testNotification()">Test Notification</button>
            <a class="button secondary" href="index.php?logout=1">Logout</a>
          </div>
        </div>
      </header>
      <main class="shell">
        <?php render_flash(); ?>
        <?php $content(); ?>
      </main>
      <script>
        const dueNotifications = <?= json_encode($dueNotifications, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) ?>;

        async function notificationRegistration() {
          if (!('serviceWorker' in navigator)) {
            return null;
          }
          try {
            const registration = await navigator.serviceWorker.register('./sw.js?v=4', { scope: './' });
            await registration.update();
            const ready = navigator.serviceWorker.ready;
            const timeout = new Promise((resolve) => {
              setTimeout(() => resolve(null), 2500);
            });
            return await Promise.race([ready, timeout]);
          } catch (error) {
            console.warn('Service worker registration failed', error);
            return null;
          }
        }

        async function ensureNotificationPermission() {
          if (!('Notification' in window)) {
            alert('This browser does not support system notifications.');
            return false;
          }
          if (Notification.permission === 'granted') {
            return true;
          }
          if (Notification.permission === 'denied') {
            alert('Notifications are blocked. Enable them in browser/site settings.');
            return false;
          }
          const permission = await Notification.requestPermission();
          if (permission === 'granted') {
            alert('Permission allowed. Press Test Notification again to send the system tray notification.');
          } else {
            console.warn('Notification permission was not allowed.');
          }
          return false;
        }

        async function showBrowserNotification(title, options) {
          const registration = await notificationRegistration();
          if (registration && 'showNotification' in registration) {
            await registration.showNotification(title, options);
            return true;
          }

          if (navigator.serviceWorker && navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
              type: 'SHOW_NOTIFICATION',
              title,
              options
            });
            return true;
          }

          new Notification(title, options);
          return true;
        }

        async function testNotification() {
          if (!(await ensureNotificationPermission())) {
            return;
          }
          try {
            const shown = await showBrowserNotification('Server Manager test', {
              body: 'Browser notifications are working for this dashboard.',
              icon: 'assets/icon-192.png',
              badge: 'assets/favicon.png',
              tag: 'server-manager-test',
              requireInteraction: true
            });
            if (!shown) {
              alert('Browser accepted permission, but did not show the system notification. Check OS/browser notification settings.');
            }
          } catch (error) {
            console.error('Notification failed', error);
            alert('System notification could not be shown. Check browser and OS notification settings.');
          }
        }

        async function showDueNotificationsOnceDaily() {
          if (!dueNotifications.length || !('Notification' in window)) {
            return;
          }
          if (Notification.permission !== 'granted') {
            return;
          }
          const today = new Date().toISOString().slice(0, 10);
          const key = 'server-manager-web-renewal-notified';
          if (localStorage.getItem(key) === today) {
            return;
          }
          for (const item of dueNotifications) {
            await showBrowserNotification(item.title, {
              body: item.body,
              icon: 'assets/icon-192.png',
              badge: 'assets/favicon.png'
            });
          }
          localStorage.setItem(key, today);
        }

        showDueNotificationsOnceDaily();
      </script>
    </body>
    </html>
    <?php
}

function due_notification_payloads(array $servers): array
{
    $payloads = [];
    foreach ($servers as $server) {
        if (in_array($server['status'], ['retired', 'suspended'], true)) {
            continue;
        }
        $days = days_until($server['renewal_date'] ?? null);
        if ($days > 7) {
            continue;
        }
        $payloads[] = [
            'title' => $days < 0
                ? $server['name'] . ' renewal is overdue'
                : $server['name'] . ' renewal due soon',
            'body' => $days < 0
                ? $server['assigned_client'] . ' renewal was due ' . abs($days) . ' day(s) ago.'
                : $server['assigned_client'] . ' renewal is due in ' . $days . ' day(s).',
        ];
    }
    return $payloads;
}

function render_list_view(array $servers, array $statusLabels): void
{
    $roots = root_servers($servers);
    $vmCount = count($servers) - count($roots);
    $dueSoon = count(array_filter($roots, fn(array $server): bool => days_until($server['renewal_date'] ?? null) <= 7));
    $monthly = array_sum(array_map(fn(array $server): float => (float) $server['monthly_cost'], $roots));
    ?>
    <section class="hero">
      <div class="eyebrow">Infrastructure Overview</div>
      <h1><?= count($roots) ?> dedicated servers</h1>
      <div class="metrics">
        <div class="metric"><strong><?= $dueSoon ?></strong><span>Due soon</span></div>
        <div class="metric"><strong><?= $vmCount ?></strong><span>VMs</span></div>
        <div class="metric"><strong>PKR <?= number_format($monthly, 0) ?></strong><span>Monthly</span></div>
      </div>
    </section>

    <section class="panel">
      <div class="panel-title">
        <h2>Servers (<?= count($roots) ?>)</h2>
        <a class="button teal" href="index.php?page=form">Add Server</a>
      </div>
      <?php if (!$roots): ?>
        <div class="empty">No dedicated servers saved yet.</div>
      <?php else: ?>
        <div class="server-grid">
          <?php foreach ($roots as $server): ?>
            <?php render_server_card($server, $servers, $statusLabels); ?>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    </section>
    <?php
}

function render_reports_view(array $servers, array $statusLabels): void
{
    $roots = root_servers($servers);
    $vms = array_values(array_filter($servers, fn(array $server): bool => !empty($server['parent_id'])));
    $monthly = array_sum(array_map(fn(array $server): float => (float) $server['monthly_cost'], $roots));
    $due30 = array_values(array_filter($roots, fn(array $server): bool => days_until($server['renewal_date'] ?? null) <= 30));
    usort($due30, fn(array $a, array $b): int => strcmp((string) $a['renewal_date'], (string) $b['renewal_date']));
    $vmCpu = array_sum(array_map(fn(array $server): int => (int) ($server['vm_cpu_cores'] ?? 0), $vms));
    $vmRam = array_sum(array_map(fn(array $server): float => (float) ($server['vm_memory_gb'] ?? 0), $vms));
    $vmDisk = array_sum(array_map(fn(array $server): float => (float) ($server['vm_disk_gb'] ?? 0), $vms));
    ?>
    <section class="hero">
      <div class="eyebrow">Operational Reports</div>
      <h1>Server estate intelligence</h1>
      <div class="metrics">
        <div class="metric"><strong><?= count($roots) ?></strong><span>Dedicated</span></div>
        <div class="metric"><strong><?= count($vms) ?></strong><span>VMs</span></div>
        <div class="metric"><strong>PKR <?= number_format($monthly, 0) ?></strong><span>Monthly</span></div>
      </div>
    </section>

    <div class="report-stack">
      <section class="panel">
        <div class="panel-title"><h2>Dedicated Servers Report</h2></div>
        <div class="report-metrics">
          <?php report_metric('Total', (string) count($roots)); ?>
          <?php report_metric('Active', (string) count_status($roots, 'active')); ?>
          <?php report_metric('Due / Overdue', (string) count(array_filter($roots, fn(array $server): bool => days_until($server['renewal_date'] ?? null) <= 7))); ?>
          <?php report_metric('Monthly', 'PKR ' . number_format($monthly, 0)); ?>
        </div>
        <?php foreach ($statusLabels as $status => $label): ?>
          <?php report_bar($label, count_status($roots, $status), max(count($roots), 1)); ?>
        <?php endforeach; ?>
      </section>

      <section class="panel">
        <div class="panel-title"><h2>Virtual Machines Report</h2></div>
        <div class="report-metrics">
          <?php report_metric('VMs', (string) count($vms)); ?>
          <?php report_metric('vCPU', (string) $vmCpu); ?>
          <?php report_metric('RAM', number_format($vmRam, 1) . ' GB'); ?>
          <?php report_metric('Disk', number_format($vmDisk, 1) . ' GB'); ?>
        </div>
        <?php report_group_bars(group_count($vms, 'operating_system'), count($vms), 'No VM operating systems recorded.'); ?>
      </section>

      <section class="panel">
        <div class="panel-title"><h2>Renewal Due Report</h2></div>
        <div class="report-metrics">
          <?php report_metric('Overdue', (string) count(array_filter($roots, fn(array $server): bool => days_until($server['renewal_date'] ?? null) < 0))); ?>
          <?php report_metric('7 Days', (string) count(array_filter($roots, fn(array $server): bool => days_until($server['renewal_date'] ?? null) >= 0 && days_until($server['renewal_date'] ?? null) <= 7))); ?>
          <?php report_metric('30 Days', (string) count($due30)); ?>
        </div>
        <?php if (!$due30): ?>
          <div class="empty">No dedicated server renewals due in the next 30 days.</div>
        <?php else: ?>
          <?php foreach (array_slice($due30, 0, 8) as $server): ?>
            <?php
              $days = days_until($server['renewal_date'] ?? null);
              $renewal = date_for_input($server['renewal_date'] ?? null);
              report_line($server['name'], $server['assigned_client'] . ' - ' . $renewal, $days < 0 ? abs($days) . 'd overdue' : $days . 'd left');
            ?>
          <?php endforeach; ?>
        <?php endif; ?>
      </section>

      <section class="panel">
        <div class="panel-title"><h2>Cost & Provider Report</h2></div>
        <?php report_money_bars(group_sum($roots, 'provider', 'monthly_cost'), $monthly, 'No provider cost data available.'); ?>
        <hr>
        <?php report_money_bars(group_sum($roots, 'assigned_client', 'monthly_cost'), $monthly, 'No client cost data available.'); ?>
      </section>

      <section class="panel">
        <div class="panel-title"><h2>Host & VM Allocation Report</h2></div>
        <?php if (!$roots): ?>
          <div class="empty">No dedicated hosts available.</div>
        <?php else: ?>
          <?php foreach ($roots as $host): ?>
            <?php
              $children = child_servers($servers, (string) $host['id']);
              $cpu = array_sum(array_map(fn(array $server): int => (int) ($server['vm_cpu_cores'] ?? 0), $children));
              $ram = array_sum(array_map(fn(array $server): float => (float) ($server['vm_memory_gb'] ?? 0), $children));
              $disk = array_sum(array_map(fn(array $server): float => (float) ($server['vm_disk_gb'] ?? 0), $children));
              report_line($host['name'], count($children) . ' VM(s), ' . $cpu . ' vCPU, ' . number_format($ram, 1) . ' GB RAM, ' . number_format($disk, 1) . ' GB disk', $host['provider']);
            ?>
          <?php endforeach; ?>
        <?php endif; ?>
      </section>

      <section class="panel">
        <div class="panel-title"><h2>Client Allocation Report</h2></div>
        <?php report_group_bars(group_count($servers, 'assigned_client'), count($servers), 'No client allocation data available.'); ?>
      </section>
    </div>
    <?php
}

function render_detail_view(array $servers, array $statusLabels): void
{
    $id = (string) ($_GET['id'] ?? '');
    $server = find_server($servers, $id);

    if (!$server) {
        echo '<div class="empty">Server not found.</div>';
        return;
    }

    $isVm = !empty($server['parent_id']);
    $children = child_servers($servers, (string) $server['id']);
    $parent = $isVm ? find_server($servers, (string) $server['parent_id']) : null;
    ?>
    <section class="hero">
      <div class="eyebrow"><?= $isVm ? 'Virtual Machine' : 'Dedicated Server' ?></div>
      <h1><?= h($server['name']) ?></h1>
      <p><?= h(first_ip((string) $server['ip_address'])) ?> &nbsp; <span class="chip <?= h($server['status']) ?>"><?= h($statusLabels[$server['status']] ?? $server['status']) ?></span></p>
      <div class="actions">
        <a class="button secondary" href="index.php">Back</a>
        <a class="button secondary" href="index.php?page=form&id=<?= urlencode($server['id']) ?>">Edit</a>
        <form method="post">
          <input type="hidden" name="action" value="send_whatsapp">
          <input type="hidden" name="id" value="<?= h($server['id']) ?>">
          <button class="button teal" type="submit">Send WhatsApp</button>
        </form>
        <?php if (!$isVm): ?>
          <a class="button teal" href="index.php?page=form&parent_id=<?= urlencode($server['id']) ?>">Add VM</a>
        <?php endif; ?>
        <form method="post" onsubmit="return confirm('Delete this record?');">
          <input type="hidden" name="action" value="delete">
          <input type="hidden" name="id" value="<?= h($server['id']) ?>">
          <button class="danger" type="submit">Delete</button>
        </form>
      </div>
    </section>

    <?php if ($isVm): ?>
      <section class="panel">
        <div class="panel-title"><h2>VM Configuration</h2></div>
        <div class="info-grid">
          <?php info('Host Server', $parent['name'] ?? 'Dedicated host'); ?>
          <?php info('Operating System', $server['operating_system']); ?>
          <?php info('vCPU', $server['vm_cpu_cores'] ?: 'Not set'); ?>
          <?php info('Memory', $server['vm_memory_gb'] ? number_format((float) $server['vm_memory_gb'], 1) . ' GB' : 'Not set'); ?>
          <?php info('Disk', $server['vm_disk_gb'] ? number_format((float) $server['vm_disk_gb'], 1) . ' GB' : 'Not set'); ?>
          <?php info('Datastore', $server['vm_storage'] ?: 'Not set'); ?>
          <?php info('Role / Purpose', $server['vm_role'] ?: 'Not set'); ?>
          <?php info('Login User', $server['login_user']); ?>
          <?php info('Assigned Client', $server['assigned_client']); ?>
          <?php info('Client WhatsApp Phone', ($server['client_phone'] ?? '') ?: 'Not added'); ?>
        </div>
      </section>
    <?php else: ?>
      <section class="panel">
        <div class="panel-title"><h2>Server Information</h2></div>
        <div class="info-grid">
          <?php info('Provider', $server['provider']); ?>
          <?php info('Location', $server['location']); ?>
          <?php info('Specification', $server['specification']); ?>
          <?php info('OS / Hypervisor', $server['operating_system']); ?>
          <?php info('Login User', $server['login_user']); ?>
        </div>
      </section>
      <section class="panel">
        <div class="panel-title"><h2>Billing & Client</h2></div>
        <div class="info-grid">
          <?php info('Assigned Client', $server['assigned_client']); ?>
          <?php info('Client WhatsApp Phone', ($server['client_phone'] ?? '') ?: 'Not added'); ?>
          <?php info('Monthly Cost', 'PKR ' . number_format((float) $server['monthly_cost'], 2)); ?>
          <?php info('Purchase Date', date_for_input($server['purchase_date'])); ?>
          <?php info('Renewal Date', date_for_input($server['renewal_date']) . ' (' . renewal_text($server['renewal_date']) . ')'); ?>
        </div>
      </section>
      <section class="panel">
        <div class="panel-title">
          <h2>Sub Servers / VMs</h2>
          <a class="button teal" href="index.php?page=form&parent_id=<?= urlencode($server['id']) ?>">Add VM</a>
        </div>
        <?php if (!$children): ?>
          <div class="empty">No VMs added under this server yet.</div>
        <?php else: ?>
          <div class="server-grid">
            <?php foreach ($children as $child): ?>
              <?php render_server_card($child, $servers, $statusLabels, true); ?>
            <?php endforeach; ?>
          </div>
        <?php endif; ?>
      </section>
    <?php endif; ?>

    <section class="panel">
      <div class="panel-title"><h2>Notes</h2></div>
      <p><?= h($server['notes'] ?: 'No notes added.') ?></p>
    </section>
    <?php
}

function render_form_view(array $servers, array $statuses, array $statusLabels): void
{
    $id = (string) ($_GET['id'] ?? '');
    $parentId = (string) ($_GET['parent_id'] ?? '');
    $editing = $id !== '' ? find_server($servers, $id) : null;
    $parent = $parentId !== '' ? find_server($servers, $parentId) : null;
    $isVm = $editing ? !empty($editing['parent_id']) : $parent !== null;
    $form = $editing ?? default_form($parent);
    ?>
    <section class="hero">
      <div class="eyebrow"><?= $editing ? 'Edit Record' : ($isVm ? 'Add Virtual Machine' : 'Add Dedicated Server') ?></div>
      <h1><?= $editing ? h($form['name']) : ($isVm ? 'Create a VM under ' . h($parent['name'] ?? 'host') : 'Create a dedicated server') ?></h1>
    </section>

    <section class="panel">
      <form method="post" class="grid">
        <input type="hidden" name="action" value="save">
        <input type="hidden" name="id" value="<?= h($form['id']) ?>">
        <input type="hidden" name="parent_id" value="<?= h((string) ($form['parent_id'] ?? $parentId)) ?>">

        <label><?= $isVm ? 'VM Name' : 'Server Name' ?>
          <input name="name" value="<?= h($form['name']) ?>" required>
        </label>
        <label>IP Address
          <input name="ip_address" value="<?= h($form['ip_address']) ?>" required>
        </label>

        <?php if (!$isVm): ?>
          <div class="split">
            <label>Provider<input name="provider" value="<?= h($form['provider']) ?>" required></label>
            <label>Location<input name="location" value="<?= h($form['location']) ?>" required></label>
          </div>
          <label>Dedicated Server Specification
            <textarea name="specification" required><?= h($form['specification']) ?></textarea>
          </label>
          <label>Host OS / Hypervisor
            <input name="operating_system" value="<?= h($form['operating_system']) ?>" required>
          </label>
        <?php else: ?>
          <input type="hidden" name="provider" value="<?= h($form['provider']) ?>">
          <input type="hidden" name="location" value="<?= h($form['location']) ?>">
          <input type="hidden" name="specification" value="<?= h($form['specification']) ?>">
          <label>VM OS Type / Version
            <input name="operating_system" value="<?= h($form['operating_system']) ?>" required>
          </label>
          <label>VM Role / Purpose
            <input name="vm_role" value="<?= h((string) ($form['vm_role'] ?? '')) ?>">
          </label>
          <div class="split">
            <label>vCPU<input name="vm_cpu_cores" type="number" min="0" step="1" value="<?= h((string) ($form['vm_cpu_cores'] ?? '')) ?>" required></label>
            <label>RAM GB<input name="vm_memory_gb" type="number" min="0" step="0.01" value="<?= h((string) ($form['vm_memory_gb'] ?? '')) ?>" required></label>
          </div>
          <div class="split">
            <label>Disk GB<input name="vm_disk_gb" type="number" min="0" step="0.01" value="<?= h((string) ($form['vm_disk_gb'] ?? '')) ?>" required></label>
            <label>Datastore<input name="vm_storage" value="<?= h((string) ($form['vm_storage'] ?? '')) ?>"></label>
          </div>
        <?php endif; ?>

        <div class="split">
          <label>Login User<input name="login_user" value="<?= h($form['login_user']) ?>" required></label>
          <label>Status
            <select name="status">
              <?php foreach ($statuses as $status): ?>
                <option value="<?= h($status) ?>" <?= selected((string) $form['status'], $status) ?>><?= h($statusLabels[$status]) ?></option>
              <?php endforeach; ?>
            </select>
          </label>
        </div>
        <label>Assigned Client
          <input name="assigned_client" value="<?= h($form['assigned_client']) ?>" required>
        </label>
        <label>Client WhatsApp Phone
          <input name="client_phone" value="<?= h((string) ($form['client_phone'] ?? '')) ?>" placeholder="923001234567">
        </label>

        <?php if (!$isVm): ?>
          <div class="split">
            <label>Monthly Cost<input name="monthly_cost" type="number" min="0" step="0.01" value="<?= h((string) $form['monthly_cost']) ?>" required></label>
            <label>Purchase Date<input name="purchase_date" type="date" value="<?= h(date_for_input($form['purchase_date'])) ?>" required></label>
          </div>
          <label>Renewal / Due Date
            <input name="renewal_date" type="date" value="<?= h(date_for_input($form['renewal_date'])) ?>" required>
          </label>
        <?php else: ?>
          <input type="hidden" name="monthly_cost" value="0">
          <input type="hidden" name="purchase_date" value="<?= h(date_for_input($form['purchase_date'])) ?>">
          <input type="hidden" name="renewal_date" value="<?= h(date_for_input($form['renewal_date'])) ?>">
        <?php endif; ?>

        <label>Notes
          <textarea name="notes"><?= h($form['notes']) ?></textarea>
        </label>
        <div class="actions">
          <button type="submit">Save</button>
          <a class="button secondary" href="<?= $isVm && ($form['parent_id'] ?? $parentId) ? 'index.php?page=detail&id=' . urlencode((string) ($form['parent_id'] ?? $parentId)) : 'index.php' ?>">Cancel</a>
        </div>
      </form>
    </section>
    <?php
}

function render_server_card(array $server, array $allServers, array $statusLabels, bool $vm = false): void
{
    $children = child_servers($allServers, (string) $server['id']);
    $isVm = $vm || !empty($server['parent_id']);
    ?>
    <a class="server-card <?= $isVm ? 'vm-card' : '' ?>" href="index.php?page=detail&id=<?= urlencode($server['id']) ?>">
      <div class="server-head">
        <div>
          <div class="server-name"><?= h($server['name']) ?></div>
          <div class="muted"><?= $isVm ? 'VM / Sub server - ' : '' ?><?= h(first_ip((string) $server['ip_address'])) ?></div>
        </div>
        <span class="chip <?= h($server['status']) ?>"><?= h($statusLabels[$server['status']] ?? $server['status']) ?></span>
      </div>
      <div class="muted"><?= h($isVm ? vm_spec_text($server) : $server['specification']) ?></div>
      <div class="muted" style="margin-top:10px;">
        <?= $isVm ? h($server['operating_system']) : h($server['assigned_client']) . ' - ' . count($children) . ' VM(s)' ?>
      </div>
    </a>
    <?php
}

function default_form(?array $parent): array
{
    return [
        'id' => '',
        'parent_id' => $parent['id'] ?? null,
        'name' => '',
        'ip_address' => '',
        'provider' => $parent['provider'] ?? '',
        'location' => $parent['location'] ?? '',
        'specification' => '',
        'operating_system' => '',
        'login_user' => 'root',
        'monthly_cost' => '',
        'purchase_date' => $parent['purchase_date'] ?? date('c'),
        'renewal_date' => $parent['renewal_date'] ?? (new DateTimeImmutable('+30 days'))->format(DateTimeInterface::ATOM),
        'assigned_client' => $parent['assigned_client'] ?? '',
        'client_phone' => $parent['client_phone'] ?? '',
        'status' => 'active',
        'notes' => '',
        'vm_cpu_cores' => '',
        'vm_memory_gb' => '',
        'vm_disk_gb' => '',
        'vm_storage' => '',
        'vm_role' => '',
    ];
}

function info(string $label, mixed $value): void
{
    echo '<div class="info"><span>' . h($label) . '</span>' . h((string) $value) . '</div>';
}

function vm_spec_text(array $server): string
{
    $parts = [];
    if (!empty($server['vm_cpu_cores'])) {
        $parts[] = $server['vm_cpu_cores'] . ' vCPU';
    }
    if (!empty($server['vm_memory_gb'])) {
        $parts[] = number_format((float) $server['vm_memory_gb'], 1) . 'GB RAM';
    }
    if (!empty($server['vm_disk_gb'])) {
        $parts[] = number_format((float) $server['vm_disk_gb'], 1) . 'GB disk';
    }
    if (!empty($server['vm_storage'])) {
        $parts[] = 'Datastore: ' . $server['vm_storage'];
    }
    return $parts ? implode(', ', $parts) : ($server['specification'] ?: 'Virtual machine');
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

function renewal_text(?string $date): string
{
    $days = days_until($date);
    return $days < 0 ? abs($days) . ' days overdue' : $days . ' days left';
}

function count_status(array $servers, string $status): int
{
    return count(array_filter($servers, fn(array $server): bool => (string) $server['status'] === $status));
}

function group_count(array $servers, string $field): array
{
    $groups = [];
    foreach ($servers as $server) {
        $key = trim((string) ($server[$field] ?? ''));
        if ($key === '') {
            continue;
        }
        $groups[$key] = ($groups[$key] ?? 0) + 1;
    }
    arsort($groups);
    return $groups;
}

function group_sum(array $servers, string $groupField, string $sumField): array
{
    $groups = [];
    foreach ($servers as $server) {
        $key = trim((string) ($server[$groupField] ?? ''));
        if ($key === '') {
            continue;
        }
        $groups[$key] = ($groups[$key] ?? 0) + (float) ($server[$sumField] ?? 0);
    }
    arsort($groups);
    return $groups;
}

function report_metric(string $label, string $value): void
{
    ?>
    <div class="report-metric">
      <strong><?= h($value) ?></strong>
      <span><?= h($label) ?></span>
    </div>
    <?php
}

function report_bar(string $label, int|float $value, int|float $total): void
{
    $percent = $total > 0 ? max(0, min(100, ($value / $total) * 100)) : 0;
    ?>
    <div class="report-row">
      <div class="report-row-head">
        <strong><?= h($label) ?></strong>
        <span><?= is_float($value) ? number_format($value, 2) : (string) $value ?></span>
      </div>
      <div class="bar"><i style="width: <?= h(number_format($percent, 2, '.', '')) ?>%;"></i></div>
    </div>
    <?php
}

function report_group_bars(array $groups, int $total, string $emptyText): void
{
    if (!$groups || $total <= 0) {
        echo '<div class="empty">' . h($emptyText) . '</div>';
        return;
    }

    foreach (array_slice($groups, 0, 6, true) as $label => $value) {
        report_bar((string) $label, (int) $value, $total);
    }
}

function report_money_bars(array $groups, float $total, string $emptyText): void
{
    if (!$groups || $total <= 0) {
        echo '<div class="empty">' . h($emptyText) . '</div>';
        return;
    }

    foreach (array_slice($groups, 0, 6, true) as $label => $value) {
        report_bar((string) $label . ' - PKR ' . number_format((float) $value, 0), (float) $value, $total);
    }
}

function report_line(string $title, string $subtitle, string $trailing): void
{
    ?>
    <div class="report-line">
      <div>
        <strong><?= h($title) ?></strong>
        <span><?= h($subtitle) ?></span>
      </div>
      <b><?= h($trailing) ?></b>
    </div>
    <?php
}

function send_whatsapp_message(array $server): void
{
    $phone = normalize_whatsapp_phone((string) ($server['client_phone'] ?? ''));
    if ($phone === '') {
        throw new RuntimeException('Add a client WhatsApp phone first.');
    }

    if (WHATSAPP_WEBHOOK_URL === '') {
        throw new RuntimeException('WhatsApp webhook URL is not configured in api/config.php.');
    }

    $invoicePdfBase64 = base64_encode(invoice_pdf($server));
    $payload = [
        'phone' => $phone,
        'message' => whatsapp_message($server),
        'pdf_base64' => $invoicePdfBase64,
        'event' => 'server.renewal_reminder',
        'timestamp' => (new DateTimeImmutable())->format(DateTimeInterface::ATOM),
        'sender' => WHATSAPP_SENDER,
        'invoice' => [
            'filename' => invoice_file_name($server),
            'pdf' => $invoicePdfBase64,
        ],
        'client' => [
            'name' => (string) ($server['assigned_client'] ?? ''),
            'phone' => $phone,
        ],
    ];

    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => [
                'Accept: application/json',
                'Content-Type: application/json',
            ],
            'content' => json_encode($payload),
            'ignore_errors' => true,
            'timeout' => 15,
        ],
    ]);

    $response = file_get_contents(WHATSAPP_WEBHOOK_URL, false, $context);
    $statusLine = $http_response_header[0] ?? '';
    $ok = preg_match('/\s2\d\d\s/', $statusLine) === 1;
    $decoded = is_string($response) ? json_decode($response, true) : null;

    if (!$ok || (is_array($decoded) && ($decoded['success'] ?? true) === false)) {
        $message = is_array($decoded)
            ? (string) ($decoded['error'] ?? $decoded['message'] ?? 'WhatsApp gateway error')
            : 'WhatsApp gateway error';
        throw new RuntimeException($message);
    }
}

function normalize_whatsapp_phone(string $phone): string
{
    return preg_replace('/\D+/', '', $phone) ?? '';
}

function whatsapp_message(array $server): string
{
    $client = (string) ($server['assigned_client'] ?? 'Client');
    $name = (string) ($server['name'] ?? 'Server');
    $ip = first_ip((string) ($server['ip_address'] ?? ''));

    if (!empty($server['parent_id'])) {
        return "*Dear {$client},*\n\n"
            . "Server details for *{$name}:*\n"
            . "IP: {$ip}\n"
            . 'OS: ' . (string) ($server['operating_system'] ?? '') . "\n"
            . 'Specs: ' . vm_spec_text($server) . "\n\n"
            . 'Best regards,';
    }

    $renewal = date_for_input((string) ($server['renewal_date'] ?? ''));
    $days = days_until((string) ($server['renewal_date'] ?? ''));
    $dueText = $days < 0 ? 'overdue by ' . abs($days) . ' day(s)' : 'due in ' . $days . ' day(s)';
    $amount = number_format((float) ($server['monthly_cost'] ?? 0), 0);
    $monthName = (new DateTimeImmutable($server['renewal_date'] ?? 'now'))->format('F Y');

    $line = "\n" . str_repeat('▬', 30) . "\n";

    return "*OneNet Solutions*\n"
        . "NTN# 1443348-6\n"
        . "Shop No.1, 83-D, The Mall, Lahore\n"
        . "+923214424625{$line}"
        . "*INVOICE*\n"
        . "Invoice No.: OneNetSol-" . substr((string) ($server['id'] ?? ''), 0, 8) . "\n"
        . "Dated: {$renewal}{$line}"
        . "*Bill To:*\n"
        . "{$client}\n"
        . "Server: {$name} ({$ip}){$line}"
        . "Qty  Description                          Unit Price     Total\n"
        . str_repeat('─', 55) . "\n"
        . "1    Monthly Services Charges for         PKR {$amount}   PKR {$amount}\n"
        . "     the Month of {$monthName}{$line}"
        . str_pad('Total', 35) . "PKR {$amount}\n"
        . str_pad('Grand Total', 35) . "PKR {$amount}{$line}"
        . "_Renewal {$dueText}._\n"
        . "Please arrange payment to avoid service interruption.\n\n"
        . "Thank you for your business.";
}

function first_ip(string $ipAddress): string
{
    $parts = preg_split('/[,;\s]+/', $ipAddress) ?: [];
    foreach ($parts as $part) {
        $part = trim($part);
        if ($part !== '') {
            return $part;
        }
    }
    return $ipAddress;
}

function invoice_file_name(array $server): string
{
    $client = preg_replace('/[^A-Za-z0-9]+/', '_', (string) ($server['assigned_client'] ?? 'Client')) ?: 'Client';
    $client = trim($client, '_') ?: 'Client';
    $date = date_for_input((string) ($server['renewal_date'] ?? ''));
    return 'OneNetSol_' . $client . '_' . str_replace('-', '', $date) . '.pdf';
}

function invoice_pdf(array $server): string
{
    $renewal = date_for_input((string) ($server['renewal_date'] ?? ''));
    $invoiceNo = 'OneNetSol-' . substr((string) ($server['id'] ?? 'invoice'), 0, 8);
    $amount = 'PKR ' . number_format((float) ($server['monthly_cost'] ?? 0), 2);
    $lines = [
        ['OneNet Solutions Pakistan', 50, 790, 18],
        ['INVOICE', 455, 790, 20],
        ['Invoice No: ' . $invoiceNo, 50, 750, 11],
        ['Invoice Date: ' . $renewal, 50, 734, 11],
        ['Bill To: ' . (string) ($server['assigned_client'] ?? 'Client'), 50, 704, 12],
        ['Server Renewal Invoice', 50, 660, 14],
        ['Description', 55, 625, 11],
        ['Amount', 470, 625, 11],
        ['Renewal for ' . (string) ($server['name'] ?? 'Server'), 55, 595, 11],
        ['Server IP: ' . first_ip((string) ($server['ip_address'] ?? '')), 55, 579, 11],
        ['Provider: ' . (string) ($server['provider'] ?? ''), 55, 563, 11],
        [$amount, 450, 595, 11],
        ['Total Due', 360, 520, 13],
        [$amount, 450, 520, 13],
        ['Please arrange renewal to avoid service interruption.', 50, 470, 11],
        ['Thank you for your business.', 50, 446, 11],
    ];

    return simple_pdf($lines);
}

function simple_pdf(array $lines): string
{
    $content = "BT\n";
    foreach ($lines as [$text, $x, $y, $size]) {
        $content .= "/F1 {$size} Tf\n";
        $content .= "{$x} {$y} Td\n";
        $content .= '(' . pdf_escape((string) $text) . ") Tj\n";
        $content .= (-$x) . ' ' . (-$y) . " Td\n";
    }
    $content .= 'ET';

    $objects = [
        "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
        "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
        "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
        "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
        "5 0 obj\n<< /Length " . strlen($content) . " >>\nstream\n{$content}\nendstream\nendobj\n",
    ];

    $pdf = "%PDF-1.4\n";
    $offsets = [0];
    foreach ($objects as $object) {
        $offsets[] = strlen($pdf);
        $pdf .= $object;
    }
    $xrefOffset = strlen($pdf);
    $pdf .= "xref\n0 " . (count($objects) + 1) . "\n";
    $pdf .= "0000000000 65535 f \n";
    foreach (array_slice($offsets, 1) as $offset) {
        $pdf .= str_pad((string) $offset, 10, '0', STR_PAD_LEFT) . " 00000 n \n";
    }
    $pdf .= "trailer\n<< /Size " . (count($objects) + 1) . " /Root 1 0 R >>\n";
    $pdf .= "startxref\n{$xrefOffset}\n%%EOF";

    return $pdf;
}

function pdf_escape(string $value): string
{
    $value = preg_replace('/[^\x20-\x7E]/', ' ', $value) ?? '';
    return str_replace(['\\', '(', ')'], ['\\\\', '\\(', '\\)'], $value);
}

function set_flash(string $type, string $message): void
{
    $_SESSION['server_manager_flash'] = ['type' => $type, 'message' => $message];
}

function render_flash(): void
{
    $flash = $_SESSION['server_manager_flash'] ?? null;
    unset($_SESSION['server_manager_flash']);
    if (!is_array($flash)) {
        return;
    }

    $type = ($flash['type'] ?? '') === 'success' ? 'success' : 'error';
    echo '<div class="flash ' . h($type) . '">' . h((string) ($flash['message'] ?? '')) . '</div>';
}

function h(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

function selected(string $actual, string $expected): string
{
    return $actual === $expected ? 'selected' : '';
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
        body { align-items: center; background: linear-gradient(135deg, #e0f2fe, #f5f3ff, #fffbeb); color: #111827; display: flex; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; justify-content: center; margin: 0; min-height: 100vh; padding: 20px; }
        form { background: white; border: 1px solid #e5e7eb; border-radius: 12px; box-shadow: 0 12px 30px rgba(17,24,39,.1); max-width: 390px; padding: 20px; width: 100%; }
        h1 { align-items: center; display: flex; font-size: 22px; gap: 10px; margin: 0 0 16px; }
        h1 img { border-radius: 8px; height: 34px; width: 34px; }
        label { color: #4b5563; display: grid; font-size: 12px; font-weight: 800; gap: 6px; }
        input { border: 1px solid #e5e7eb; border-radius: 8px; font: inherit; min-height: 42px; padding: 10px 11px; }
        button { background: #111827; border: 0; border-radius: 8px; color: white; cursor: pointer; font: inherit; font-weight: 800; margin-top: 14px; min-height: 42px; width: 100%; }
        .error { color: #991b1b; font-size: 14px; margin-bottom: 12px; }
      </style>
    </head>
    <body>
      <form method="post">
        <h1><img src="assets/icon-192.png" alt=""> Server Manager</h1>
        <?php if ($error): ?><div class="error"><?= h($error) ?></div><?php endif; ?>
        <input type="hidden" name="action" value="login">
        <label>Password <input name="password" type="password" required autofocus></label>
        <button type="submit">Sign In</button>
      </form>
    </body>
    </html>
    <?php
}
