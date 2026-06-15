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
    respond(['data' => $statement->fetchAll()]);
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
        ':status' => (string) $payload['status'],
        ':notes' => (string) $payload['notes'],
        ':vm_cpu_cores' => empty($payload['vm_cpu_cores']) ? null : (int) $payload['vm_cpu_cores'],
        ':vm_memory_gb' => empty($payload['vm_memory_gb']) ? null : (float) $payload['vm_memory_gb'],
        ':vm_disk_gb' => empty($payload['vm_disk_gb']) ? null : (float) $payload['vm_disk_gb'],
        ':vm_storage' => empty($payload['vm_storage']) ? null : (string) $payload['vm_storage'],
        ':vm_role' => empty($payload['vm_role']) ? null : (string) $payload['vm_role'],
    ]);

    respond(['data' => ['saved' => true]]);
}

function delete_server(): void
{
    $id = $_GET['id'] ?? '';
    if ($id === '') {
        respond(['error' => 'Missing id'], 422);
    }

    $statement = db()->prepare('DELETE FROM servers WHERE id = :id OR parent_id = :id');
    $statement->execute([':id' => $id]);
    respond(['data' => ['deleted' => true]]);
}

function respond(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
