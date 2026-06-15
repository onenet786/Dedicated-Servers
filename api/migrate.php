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
    ensure_billing_events_table($pdo, $changes);
    migrate_billing_history_json($pdo, $changes);

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

function ensure_billing_events_table(PDO $pdo, array &$changes): void
{
    $statement = $pdo->query("
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'billing_events'
    ");
    if ((int) $statement->fetchColumn() > 0) {
        return;
    }

    $pdo->exec("
        CREATE TABLE billing_events (
            id VARCHAR(64) PRIMARY KEY,
            server_id VARCHAR(64) NOT NULL,
            event_type VARCHAR(40) NOT NULL,
            event_date VARCHAR(40) NOT NULL,
            amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
            message TEXT NOT NULL,
            next_due_date VARCHAR(40) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_billing_events_server_id (server_id),
            INDEX idx_billing_events_event_date (event_date)
        )
    ");
    $changes[] = 'Created table billing_events';
}

function migrate_billing_history_json(PDO $pdo, array &$changes): void
{
    if (!column_exists($pdo, 'billing_history')) {
        return;
    }

    $rows = $pdo->query("SELECT id, billing_history FROM servers WHERE billing_history IS NOT NULL AND billing_history <> ''")->fetchAll();
    $inserted = 0;
    $statement = $pdo->prepare("
        INSERT IGNORE INTO billing_events (
            id, server_id, event_type, event_date, amount, message, next_due_date
        ) VALUES (
            :id, :server_id, :event_type, :event_date, :amount, :message, :next_due_date
        )
    ");

    foreach ($rows as $row) {
        $history = json_decode((string) ($row['billing_history'] ?? '[]'), true);
        if (!is_array($history)) {
            continue;
        }
        foreach ($history as $event) {
            if (!is_array($event)) {
                continue;
            }
            $eventDate = (string) ($event['date'] ?? date('c'));
            $type = (string) ($event['type'] ?? 'invoice_sent');
            $message = (string) ($event['message'] ?? '');
            $statement->execute([
                ':id' => billing_event_id((string) $row['id'], $type, $eventDate, $message),
                ':server_id' => (string) $row['id'],
                ':event_type' => $type,
                ':event_date' => $eventDate,
                ':amount' => (float) ($event['amount'] ?? 0),
                ':message' => $message,
                ':next_due_date' => empty($event['next_due_date']) ? null : (string) $event['next_due_date'],
            ]);
            $inserted += (int) ($statement->rowCount() > 0);
        }
    }

    if ($inserted > 0) {
        $changes[] = "Migrated {$inserted} billing history events";
    }
}

function billing_event_id(string $serverId, string $type, string $eventDate, string $message): string
{
    return substr(hash('sha256', $serverId . '|' . $type . '|' . $eventDate . '|' . $message), 0, 32);
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
