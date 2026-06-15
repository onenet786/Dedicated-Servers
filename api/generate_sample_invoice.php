<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

// Minimal standalone PDF generator copied from index.php's invoice_pdf primitives.
function begin_pdf(): array
{
    return ['content' => '', 'objects' => []];
}

function text(array &$pdf, string $str, float $x, float $y, float $size, string $font = '/F1', string $color = '0 0 0'): void
{
    $pdf['content'] .= "BT\n{$color} rg\n{$font} {$size} Tf\n{$x} {$y} Td\n(" . pdf_escape($str) . ") Tj\nET\n";
}

function rect_fill(array &$pdf, float $x, float $y, float $w, float $h, string $color): void
{
    $pdf['content'] .= "{$color} rg\n{$x} {$y} {$w} {$h} re\nf\n";
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

    // Header bars
    rect_fill($pdf, 40, 800, 220, 12, '0.976 0.451 0.086');
    rect_fill($pdf, 352, 800, 220, 12, '0.133 0.773 0.369');

    // Badge
    $badgeW = 120; $badgeH = 28;
    $badgeX = (612 / 2) - ($badgeW / 2);
    $badgeY = 788;
    rect_fill($pdf, $badgeX, $badgeY, $badgeW, $badgeH, '1 1 1');
    line($pdf, $badgeX, $badgeY + $badgeH, $badgeX + $badgeW, $badgeY + $badgeH, '0.976 0.451 0.086');
    line($pdf, $badgeX, $badgeY, $badgeX + $badgeW, $badgeY, '0.976 0.451 0.086');
    line($pdf, $badgeX, $badgeY, $badgeX, $badgeY + $badgeH, '0.976 0.451 0.086');
    line($pdf, $badgeX + $badgeW, $badgeY, $badgeX + $badgeW, $badgeY + $badgeH, '0.976 0.451 0.086');
    text($pdf, 'Invoice', $badgeX + ($badgeW / 2) - 18, $badgeY + 8, 14, '/F1B', '0.133 0.773 0.369');

    // Company
    text($pdf, 'OneNet Solutions', 50, 760, 14, '/F1B', '0.133 0.773 0.369');
    text($pdf, 'NTN# 1443348-6', 50, 744, 9, '/F1', '0.2 0.2 0.2');
    text($pdf, 'Shop No.1, 83-D, The Mall, Lahore', 50, 730, 9, '/F1', '0.2 0.2 0.2');
    text($pdf, '+923214424625', 50, 716, 9, '/F1', '0.2 0.2 0.2');

    // Invoice meta
    text($pdf, 'Dated: ' . $renewalFormatted, 360, 760, 10, '/F1', '0 0 0');
    text($pdf, 'Invoice No.: ' . $invoiceNo, 360, 744, 10, '/F1', '0 0 0');

    // Bill To & table
    text($pdf, 'Bill To:', 50, 700, 10, '/F1', '0.133 0.773 0.369');
    text($pdf, $client, 50, 684, 12, '/F1B', '0 0 0');
    text($pdf, $name, 50, 668, 10, '/F1', '0 0 0');
    if ($location !== '') {
        text($pdf, $location, 50, 652, 10, '/F1', '0 0 0');
    }

    $tableTop = 620; $tableLeft = 40; $tableRight = 572;
    $col1 = 60; $col2 = 120; $col3 = 420; $col4 = 500; $rowH = 20;
    rect_fill($pdf, $tableLeft, $tableTop - $rowH, $tableRight - $tableLeft, $rowH, '0.965 0.98 0.96');
    text($pdf, 'Qty', $col1, $tableTop - 6, 9, '/F1B', '0.133 0.773 0.369');
    text($pdf, 'Description', $col2, $tableTop - 6, 9, '/F1B', '0.133 0.773 0.369');
    text($pdf, 'Unit Price', $col3, $tableTop - 6, 9, '/F1B', '0.133 0.773 0.369');
    text($pdf, 'Total', $col4, $tableTop - 6, 9, '/F1B', '0.133 0.773 0.369');

    $rowY = $tableTop - $rowH - 6;
    rect_fill($pdf, $tableLeft, $rowY - 18, $tableRight - $tableLeft, 18, '1 1 1');
    text($pdf, '1', $col1, $rowY - 4, 10, '/F1', '0 0 0');
    text($pdf, 'Monthly Services Charges for the Month of ' . $monthYear, $col2, $rowY - 4, 9, '/F1', '0 0 0');
    text($pdf, 'PKR ' . $amount, $col3, $rowY - 4, 10, '/F1', '0 0 0');
    text($pdf, 'PKR ' . $amount, $col4, $rowY - 4, 10, '/F1', '0 0 0');

    // Totals
    $vlineY2 = $rowY - 18 - 10; $vlineY1 = $tableTop;
    line($pdf, $tableLeft, $vlineY1, $tableRight, $vlineY1, '0.6 0.6 0.6');
    line($pdf, $tableLeft, $vlineY2, $tableRight, $vlineY2, '0.6 0.6 0.6');

    $totalY = $vlineY2 - 20;
    text($pdf, 'Total', 360, $totalY - 4, 11, '/F1B', '0 0 0');
    text($pdf, 'PKR ' . $amount, $col4, $totalY - 4, 11, '/F1B', '0 0 0');

    $grandY = $totalY - 26;
    rect_fill($pdf, $tableLeft, $grandY - 14, $tableRight - $tableLeft, 18, '0.133 0.773 0.369');
    text($pdf, 'Grand Total', 340, $grandY - 4, 11, '/F1B', '1 1 1');
    text($pdf, 'PKR ' . $amount, $col4, $grandY - 4, 11, '/F1B', '1 1 1');

    text($pdf, 'Thank you for your business.', 50, $grandY - 50, 10, '/F1', '0.2 0.2 0.2');

    return end_pdf($pdf);
}

// Sample data
$sample = [
    'id' => 'sample12345',
    'renewal_date' => (new DateTimeImmutable('+5 days'))->format(DateTimeInterface::ATOM),
    'monthly_cost' => 40000,
    'assigned_client' => 'Adnan Centre',
    'location' => 'ShorKot Cannntt',
    'name' => 'Monthly Services',
];

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="sample_invoice.pdf"');
echo invoice_pdf($sample);
