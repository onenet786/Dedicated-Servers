<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

defined('WHATSAPP_WEBHOOK_URL') || define('WHATSAPP_WEBHOOK_URL', '');
defined('WHATSAPP_SENDER') || define('WHATSAPP_SENDER', 'reports4');

header('Content-Type: application/json');

try {
    require_cron_key();

    $now = new DateTimeImmutable('now', new DateTimeZone('America/Los_Angeles'));
    $force = ($_GET['force'] ?? '') === '1';
    if (!$force && (int) $now->format('G') !== 12) {
        respond([
            'data' => [
                'ran' => false,
                'message' => 'Skipped. Cron sends only during 12 PM PST/PDT.',
                'server_time_pst' => $now->format(DateTimeInterface::ATOM),
            ],
        ]);
    }

    $summary = run_whatsapp_billing_cron($now);
    respond(['data' => $summary]);
} catch (Throwable $exception) {
    respond(['error' => $exception->getMessage()], 500);
}

function require_cron_key(): void
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $apiKey = $headers['X-Api-Key'] ?? $headers['x-api-key'] ?? ($_GET['key'] ?? '');

    if (!hash_equals(API_KEY, (string) $apiKey)) {
        respond(['error' => 'Unauthorized'], 401);
    }
}

function run_whatsapp_billing_cron(DateTimeImmutable $now): array
{
    $servers = fetch_due_servers();
    $sentInvoices = 0;
    $sentReminders = 0;
    $skipped = 0;
    $errors = [];

    foreach ($servers as $server) {
        try {
            $renewal = (new DateTimeImmutable((string) $server['renewal_date']))->setTime(0, 0);
            $today = $now->setTime(0, 0);
            $days = (int) $today->diff($renewal)->format('%r%a');

            if ($days > 4 || payment_received_for_current_cycle($server)) {
                $skipped++;
                continue;
            }

            if ($days === 4) {
                if (has_event_for_cycle((string) $server['id'], 'auto_invoice_sent', (string) $server['renewal_date'])) {
                    $skipped++;
                    continue;
                }
                send_invoice_message($server);
                add_billing_event((string) $server['id'], [
                    'type' => 'auto_invoice_sent',
                    'date' => $now->format(DateTimeInterface::ATOM),
                    'amount' => (float) ($server['monthly_cost'] ?? 0),
                    'message' => 'Auto invoice sent for ' . date_for_input((string) $server['renewal_date']),
                    'renewal_date' => (string) $server['renewal_date'],
                ]);
                $sentInvoices++;
                continue;
            }

            if (!has_event_for_day((string) $server['id'], 'auto_reminder_sent', $now)) {
                send_daily_reminder_message($server);
                add_billing_event((string) $server['id'], [
                    'type' => 'auto_reminder_sent',
                    'date' => $now->format(DateTimeInterface::ATOM),
                    'amount' => (float) ($server['monthly_cost'] ?? 0),
                    'message' => 'Daily payment reminder sent',
                    'renewal_date' => (string) $server['renewal_date'],
                ]);
                $sentReminders++;
            } else {
                $skipped++;
            }
        } catch (Throwable $exception) {
            $errors[] = [
                'server_id' => (string) ($server['id'] ?? ''),
                'server' => (string) ($server['name'] ?? ''),
                'error' => $exception->getMessage(),
            ];
        }
    }

    return [
        'ran' => true,
        'server_time_pst' => $now->format(DateTimeInterface::ATOM),
        'invoice_pdf_sent' => $sentInvoices,
        'daily_text_sent' => $sentReminders,
        'skipped' => $skipped,
        'errors' => $errors,
    ];
}

function fetch_due_servers(): array
{
    $statement = db()->query("
        SELECT *
        FROM servers
        WHERE (parent_id IS NULL OR parent_id = '')
          AND status NOT IN ('retired', 'suspended')
          AND client_phone <> ''
        ORDER BY renewal_date ASC
    ");
    return $statement->fetchAll();
}

function send_invoice_message(array $server): void
{
    $phone = normalize_whatsapp_phone((string) ($server['client_phone'] ?? ''));
    if ($phone === '') {
        throw new RuntimeException('Client WhatsApp phone is missing.');
    }
    if (WHATSAPP_WEBHOOK_URL === '') {
        throw new RuntimeException('WhatsApp webhook URL is not configured.');
    }

    $invoicePdfBase64 = base64_encode(invoice_pdf($server));
    post_json(WHATSAPP_WEBHOOK_URL, [
        'phone' => $phone,
        'message' => renewal_message($server),
        'pdf_base64' => $invoicePdfBase64,
        'event' => 'server.auto_invoice',
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
        'server' => $server,
    ]);
}

function send_daily_reminder_message(array $server): void
{
    $phone = normalize_whatsapp_phone((string) ($server['client_phone'] ?? ''));
    if ($phone === '') {
        throw new RuntimeException('Client WhatsApp phone is missing.');
    }
    if (WHATSAPP_WEBHOOK_URL === '') {
        throw new RuntimeException('WhatsApp webhook URL is not configured.');
    }

    post_json(WHATSAPP_WEBHOOK_URL, [
        'phone' => $phone,
        'message' => renewal_message($server),
        'event' => 'server.daily_payment_reminder',
        'timestamp' => (new DateTimeImmutable())->format(DateTimeInterface::ATOM),
        'sender' => WHATSAPP_SENDER,
        'client' => [
            'name' => (string) ($server['assigned_client'] ?? ''),
            'phone' => $phone,
        ],
        'server' => $server,
    ]);
}

function renewal_message(array $server): string
{
    $client = (string) ($server['assigned_client'] ?? 'Client');
    $name = (string) ($server['name'] ?? 'Server');
    $ip = first_ip((string) ($server['ip_address'] ?? ''));
    $renewal = date_for_input((string) ($server['renewal_date'] ?? ''));
    $days = days_until((string) ($server['renewal_date'] ?? ''));
    $dueText = $days < 0
        ? 'was due ' . abs($days) . ' day(s) ago'
        : 'is due in ' . $days . ' day(s)';
    $amount = number_format((float) ($server['monthly_cost'] ?? 0), 2);

    return "*Dear {$client},*\n\n"
        . "Your server renewal for *{$name}* ({$renewal}) {$dueText}.\n"
        . "Server IP: {$ip}\n"
        . "Monthly cost: PKR {$amount}\n\n"
        . "Please arrange renewal to avoid service interruption.\n\n"
        . 'Best regards,';
}

function payment_received_for_current_cycle(array $server): bool
{
    $statement = db()->prepare("
        SELECT COUNT(*)
        FROM billing_events
        WHERE server_id = :server_id
          AND event_type = 'payment_received'
          AND event_date >= :renewal_date
    ");
    $statement->execute([
        ':server_id' => (string) $server['id'],
        ':renewal_date' => (string) $server['renewal_date'],
    ]);
    return (int) $statement->fetchColumn() > 0;
}

function has_event_for_cycle(string $serverId, string $type, string $renewalDate): bool
{
    $statement = db()->prepare("
        SELECT COUNT(*)
        FROM billing_events
        WHERE server_id = :server_id
          AND event_type = :event_type
          AND message LIKE :renewal_date
    ");
    $statement->execute([
        ':server_id' => $serverId,
        ':event_type' => $type,
        ':renewal_date' => '%' . date_for_input($renewalDate) . '%',
    ]);
    return (int) $statement->fetchColumn() > 0;
}

function has_event_for_day(string $serverId, string $type, DateTimeImmutable $date): bool
{
    $start = $date->setTime(0, 0)->format(DateTimeInterface::ATOM);
    $end = $date->setTime(23, 59, 59)->format(DateTimeInterface::ATOM);
    $statement = db()->prepare("
        SELECT COUNT(*)
        FROM billing_events
        WHERE server_id = :server_id
          AND event_type = :event_type
          AND event_date BETWEEN :start_at AND :end_at
    ");
    $statement->execute([
        ':server_id' => $serverId,
        ':event_type' => $type,
        ':start_at' => $start,
        ':end_at' => $end,
    ]);
    return (int) $statement->fetchColumn() > 0;
}

function add_billing_event(string $serverId, array $event): void
{
    $eventDate = (string) ($event['date'] ?? (new DateTimeImmutable())->format(DateTimeInterface::ATOM));
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

function post_json(string $url, array $payload): void
{
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

    $response = file_get_contents($url, false, $context);
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

function first_ip(string $ipAddress): string
{
    foreach (preg_split('/[,;\s]+/', $ipAddress) ?: [] as $part) {
        $part = trim($part);
        if ($part !== '') {
            return $part;
        }
    }
    return $ipAddress;
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
    $today = new DateTimeImmutable('today', new DateTimeZone('America/Los_Angeles'));
    $renewal = (new DateTimeImmutable($date))->setTime(0, 0);
    return (int) $today->diff($renewal)->format('%r%a');
}

function invoice_file_name(array $server): string
{
    $client = preg_replace('/[^A-Za-z0-9]+/', '_', (string) ($server['assigned_client'] ?? 'Client')) ?: 'Client';
    $client = trim($client, '_') ?: 'Client';
    $date = new DateTimeImmutable($server['renewal_date'] ?? 'now');
    $monthYear = $date->format('FY');
    $shortId = substr((string) ($server['id'] ?? ''), 0, 5);
    return $client . '_' . $monthYear . '_OneNetSol' . $shortId . '.pdf';
}

function invoice_pdf(array $server): string
{
    $date = new DateTimeImmutable($server['renewal_date'] ?? 'now');
    $renewalFormatted = $date->format('j M Y');
    $monthYear = $date->format('F Y');
    $invoiceNo = 'OneNetSol' . substr((string) ($server['id'] ?? 'invoice'), 0, 5);
    $amount = number_format((float) ($server['monthly_cost'] ?? 0), 0);
    $client = (string) ($server['assigned_client'] ?? 'Client');
    $location = (string) ($server['location'] ?? '');
    $name = (string) ($server['name'] ?? 'Server');
    $pdf = begin_pdf();
    $amountText = 'PKR' . $amount;

    rect_fill($pdf, 13, 802, 265, 22, '0.945 0.353 0.027');
    rect_fill($pdf, 378, 802, 217, 22, '0.502 0.839 0.129');
    rect_fill($pdf, 278, 789, 100, 38, '1 1 1');
    rect_stroke($pdf, 278, 789, 100, 38, '0.945 0.353 0.027');
    text($pdf, 'Invoice', 288, 801, 24, '/F1', '0.247 0.737 0.027');

    text($pdf, 'OneNet Solutions', 20, 748, 10, '/F1B', '0.247 0.737 0.027');
    text($pdf, 'NTN# 1443348-6&', 20, 733, 11);
    text($pdf, '&', 20, 718, 11);
    text($pdf, 'Shop No.1, 83-D, The Mall,&', 20, 704, 11);
    text($pdf, 'Lahore', 20, 690, 11);
    text($pdf, '+923214424625', 20, 676, 11);
    text($pdf, 'ONE', 256, 733, 23, '/F1B', '0.345 0.753 0.816');
    text($pdf, 'NET', 306, 733, 23, '/F1B', '0.345 0.753 0.816');
    text($pdf, 'SOLUTIONS', 266, 720, 9, '/F1B', '0.65 0.65 0.65');
    text($pdf, 'Dated:', 410, 748, 11);
    text($pdf, $renewalFormatted, 500, 748, 11);
    text($pdf, 'Invoice No.:', 410, 733, 11);
    text($pdf, $invoiceNo, 500, 733, 11);
    text($pdf, 'Bill To:', 20, 633, 11, '/F1B', '0.247 0.737 0.027');
    text($pdf, $client !== '' ? $client : 'Client', 20, 619, 11);
    text($pdf, $name, 20, 605, 11);
    if ($location !== '') {
        text($pdf, $location, 20, 591, 11);
    }

    rect_stroke($pdf, 13, 68, 582, 497, '0 0 0');
    line($pdf, 13, 541, 595, 541, '0 0 0');
    line($pdf, 57, 565, 57, 68, '0 0 0');
    line($pdf, 417, 565, 417, 68, '0 0 0');
    line($pdf, 506, 565, 506, 68, '0 0 0');
    text_right($pdf, 'Qty', 51, 552, 10, '/F1B', '0.247 0.737 0.027');
    text($pdf, 'Description', 62, 552, 10, '/F1B', '0.247 0.737 0.027');
    text_right($pdf, 'Unit Price', 499, 552, 10, '/F1B', '0.247 0.737 0.027');
    text_right($pdf, 'Total', 589, 552, 10, '/F1B', '0.247 0.737 0.027');
    text_right($pdf, '1', 52, 526, 10);
    text($pdf, 'Monthly Services Charges for the Month of ' . $monthYear, 62, 526, 10);
    text_right($pdf, $amountText, 499, 526, 10);
    text_right($pdf, $amountText, 589, 526, 10);
    text_right($pdf, 'Total', 523, 49, 10, '/F1B');
    text_right($pdf, $amountText, 590, 49, 10, '/F1B');
    text_right($pdf, 'Grand Total', 523, 32, 10, '/F1B');
    text_right($pdf, $amountText, 590, 32, 10, '/F1B');
    text($pdf, 'Thank you for your business.', 14, 8, 11, '/F1B');

    return end_pdf($pdf);
}

function begin_pdf(): array
{
    return ['content' => ''];
}

function text(array &$pdf, string $str, float $x, float $y, float $size, string $font = '/F1', string $color = '0 0 0'): void
{
    $pdf['content'] .= "BT\n{$color} rg\n{$font} {$size} Tf\n{$x} {$y} Td\n(" . pdf_escape($str) . ") Tj\nET\n";
}

function text_right(array &$pdf, string $str, float $right, float $y, float $size, string $font = '/F1', string $color = '0 0 0'): void
{
    text($pdf, $str, $right - approx_text_width($str, $size), $y, $size, $font, $color);
}

function approx_text_width(string $str, float $size): float
{
    $width = 0.0;
    foreach (str_split($str) as $char) {
        $width += preg_match('/[ilI1., ]/', $char) ? 0.28 : 0.56;
    }
    return $width * $size;
}

function rect_fill(array &$pdf, float $x, float $y, float $w, float $h, string $color): void
{
    $pdf['content'] .= "{$color} rg\n{$x} {$y} {$w} {$h} re\nf\n";
}

function rect_stroke(array &$pdf, float $x, float $y, float $w, float $h, string $color): void
{
    $pdf['content'] .= "{$color} RG\n{$x} {$y} {$w} {$h} re\nS\n";
}

function line(array &$pdf, float $x1, float $y1, float $x2, float $y2, string $color): void
{
    $pdf['content'] .= "{$color} RG\n{$x1} {$y1} m\n{$x2} {$y2} l\nS\n";
}

function end_pdf(array $pdf): string
{
    $content = $pdf['content'];
    $objects = [
        "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
        "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
        "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Resources << /Font << /F1 4 0 R /F1B 6 0 R >> >> /Contents 5 0 R >>\nendobj\n",
        "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
        "5 0 obj\n<< /Length " . strlen($content) . " >>\nstream\n{$content}\nendstream\nendobj\n",
        "6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n",
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

function respond(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
