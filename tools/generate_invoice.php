<?php
// Simple helper to generate a sample invoice PDF using existing invoice_pdf()
require_once __DIR__ . '/../api/index.php';

$sample = [
    'id' => 'sample12345',
    'renewal_date' => (new DateTimeImmutable('+5 days'))->format(DateTimeInterface::ATOM),
    'monthly_cost' => 40000,
    'assigned_client' => 'Adnan Centre',
    'location' => 'ShorKot Cannntt',
    'name' => 'Monthly Services',
];

try {
    $pdf = invoice_pdf($sample);
    $out = __DIR__ . '/sample_invoice.pdf';
    file_put_contents($out, $pdf);
    echo "Wrote sample PDF to: $out\n";
} catch (Throwable $e) {
    fwrite(STDERR, "Failed to generate PDF: " . $e->getMessage() . "\n");
    exit(1);
}
