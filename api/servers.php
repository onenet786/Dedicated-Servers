<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

try {
    require_api_key();

    match ($_SERVER['REQUEST_METHOD']) {
        'GET' => list_servers(),
        'POST' => save_server(),
        'DELETE' => delete_server(),
        default => respond(['error' => 'Method not allowed'], 405),
    };
} catch (Throwable $exception) {
    respond(['error' => $exception->getMessage()], 500);
}

function require_api_key(): void
{
    $headers = getallheaders();
    $apiKey = $headers['X-Api-Key'] ?? $headers['x-api-key'] ?? '';

    if (!hash_equals(API_KEY, $apiKey)) {
        respond(['error' => 'Unauthorized'], 401);
    }
}

function list_servers(): void
{
    $statement = db()->query('SELECT * FROM servers ORDER BY COALESCE(parent_id, id), parent_id IS NOT NULL, renewal_date ASC');
    $servers = $statement->fetchAll();
    foreach ($servers as &$server) {
        $server['billing_history'] = billing_history((string) $server['id']);
    }
    unset($server);
    respond(['data' => $servers]);
}

function save_server(): void
{
    $payload = json_decode(file_get_contents('php://input'), true);
    if (!is_array($payload)) {
        respond(['error' => 'Invalid JSON payload'], 422);
    }

    $required = [
        'id',
        'name',
        'ip_address',
        'provider',
        'location',
        'specification',
        'operating_system',
        'login_user',
        'monthly_cost',
        'purchase_date',
        'renewal_date',
        'assigned_client',
        'status',
        'notes',
    ];

    foreach ($required as $field) {
        if (!array_key_exists($field, $payload)) {
            respond(['error' => "Missing field: $field"], 422);
        }
    }

    $sql = '
        INSERT INTO servers (
            id,
            parent_id,
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
            client_phone,
            status,
            notes,
            vm_cpu_cores,
            vm_memory_gb,
            vm_disk_gb,
            vm_storage,
            vm_role
        ) VALUES (
            :id,
            :parent_id,
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
            :client_phone,
            :status,
            :notes,
            :vm_cpu_cores,
            :vm_memory_gb,
            :vm_disk_gb,
            :vm_storage,
            :vm_role
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

    $statement = db()->prepare($sql);
    $statement->execute([
        ':id' => (string) $payload['id'],
        ':parent_id' => empty($payload['parent_id']) ? null : (string) $payload['parent_id'],
        ':name' => (string) $payload['name'],
        ':ip_address' => (string) $payload['ip_address'],
        ':provider' => (string) $payload['provider'],
        ':location' => (string) $payload['location'],
        ':specification' => (string) $payload['specification'],
        ':operating_system' => (string) $payload['operating_system'],
        ':login_user' => (string) $payload['login_user'],
        ':monthly_cost' => (float) $payload['monthly_cost'],
        ':purchase_date' => (string) $payload['purchase_date'],
        ':renewal_date' => (string) $payload['renewal_date'],
        ':assigned_client' => (string) $payload['assigned_client'],
        ':client_phone' => (string) ($payload['client_phone'] ?? ''),
        ':status' => (string) $payload['status'],
        ':notes' => (string) $payload['notes'],
        ':vm_cpu_cores' => empty($payload['vm_cpu_cores']) ? null : (int) $payload['vm_cpu_cores'],
        ':vm_memory_gb' => empty($payload['vm_memory_gb']) ? null : (float) $payload['vm_memory_gb'],
        ':vm_disk_gb' => empty($payload['vm_disk_gb']) ? null : (float) $payload['vm_disk_gb'],
        ':vm_storage' => empty($payload['vm_storage']) ? null : (string) $payload['vm_storage'],
        ':vm_role' => empty($payload['vm_role']) ? null : (string) $payload['vm_role'],
    ]);

    sync_billing_history((string) $payload['id'], $payload['billing_history'] ?? []);

    respond(['data' => ['saved' => true]]);
}

function billing_history(string $serverId): array
{
    $statement = db()->prepare('
        SELECT event_type AS type, event_date AS date, amount, message, next_due_date
        FROM billing_events
        WHERE server_id = :server_id
        ORDER BY event_date DESC, created_at DESC
        LIMIT 20
    ');
    $statement->execute([':server_id' => $serverId]);
    return $statement->fetchAll();
}

function sync_billing_history(string $serverId, mixed $value): void
{
    $history = is_string($value) ? json_decode($value, true) : $value;
    if (!is_array($history)) {
        return;
    }

    foreach ($history as $event) {
        if (!is_array($event)) {
            continue;
        }
        add_billing_event($serverId, $event);
    }
}

function add_billing_event(string $serverId, array $event): void
{
    $eventDate = (string) ($event['date'] ?? date('c'));
    $type = (string) ($event['type'] ?? 'invoice_sent');
    $message = (string) ($event['message'] ?? '');
    $statement = db()->prepare('
        INSERT IGNORE INTO billing_events (
            id, server_id, event_type, event_date, amount, message, next_due_date
        ) VALUES (
            :id, :server_id, :event_type, :event_date, :amount, :message, :next_due_date
        )
    ');
    $statement->execute([
        ':id' => billing_event_id($serverId, $type, $eventDate, $message),
        ':server_id' => $serverId,
        ':event_type' => $type,
        ':event_date' => $eventDate,
        ':amount' => (float) ($event['amount'] ?? 0),
        ':message' => $message,
        ':next_due_date' => empty($event['next_due_date']) ? null : (string) $event['next_due_date'],
    ]);
}

function billing_event_id(string $serverId, string $type, string $eventDate, string $message): string
{
    return substr(hash('sha256', $serverId . '|' . $type . '|' . $eventDate . '|' . $message), 0, 32);
}

function delete_server(): void
{
    $id = $_GET['id'] ?? '';
    if ($id === '') {
        respond(['error' => 'Missing id'], 422);
    }

    db()->prepare('DELETE FROM billing_events WHERE server_id = :id OR server_id IN (SELECT id FROM servers WHERE parent_id = :id)')
        ->execute([':id' => $id]);
    db()->prepare('DELETE FROM servers WHERE id = :id OR parent_id = :id')
        ->execute([':id' => $id]);
    respond(['data' => ['deleted' => true]]);
}

function respond(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
