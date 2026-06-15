<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

header('Content-Type: application/json');

try {
    require_migration_key();

    $pdo = db();
    $changes = [];

    ensure_column($pdo, $changes, 'parent_id', 'VARCHAR(64) NULL AFTER id');
    ensure_column($pdo, $changes, 'vm_cpu_cores', 'INT NULL AFTER notes');
    ensure_column($pdo, $changes, 'vm_memory_gb', 'DECIMAL(10, 2) NULL AFTER vm_cpu_cores');
    ensure_column($pdo, $changes, 'vm_disk_gb', 'DECIMAL(10, 2) NULL AFTER vm_memory_gb');
    ensure_column($pdo, $changes, 'vm_storage', 'VARCHAR(255) NULL AFTER vm_disk_gb');
    ensure_column($pdo, $changes, 'vm_role', 'VARCHAR(255) NULL AFTER vm_storage');
    ensure_index($pdo, $changes, 'idx_servers_parent_id', 'parent_id');

    respond([
        'data' => [
            'migrated' => true,
            'changes' => $changes,
        ],
    ]);
} catch (Throwable $exception) {
    respond(['error' => $exception->getMessage()], 500);
}

function require_migration_key(): void
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $apiKey = $headers['X-Api-Key'] ?? $headers['x-api-key'] ?? ($_GET['key'] ?? '');

    if (!hash_equals(API_KEY, (string) $apiKey)) {
        respond(['error' => 'Unauthorized'], 401);
    }
}

function ensure_column(PDO $pdo, array &$changes, string $column, string $definition): void
{
    if (column_exists($pdo, $column)) {
        return;
    }

    $pdo->exec("ALTER TABLE servers ADD COLUMN $column $definition");
    $changes[] = "Added column $column";
}

function ensure_index(PDO $pdo, array &$changes, string $index, string $column): void
{
    if (index_exists($pdo, $index)) {
        return;
    }

    $pdo->exec("CREATE INDEX $index ON servers ($column)");
    $changes[] = "Added index $index";
}

function column_exists(PDO $pdo, string $column): bool
{
    $statement = $pdo->prepare("
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'servers'
          AND COLUMN_NAME = :column
    ");
    $statement->execute([':column' => $column]);

    return (int) $statement->fetchColumn() > 0;
}

function index_exists(PDO $pdo, string $index): bool
{
    $statement = $pdo->prepare("
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'servers'
          AND INDEX_NAME = :index_name
    ");
    $statement->execute([':index_name' => $index]);

    return (int) $statement->fetchColumn() > 0;
}

function respond(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
