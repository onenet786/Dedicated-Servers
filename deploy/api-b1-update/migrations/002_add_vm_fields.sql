ALTER TABLE servers
  ADD COLUMN vm_cpu_cores INT NULL AFTER notes,
  ADD COLUMN vm_memory_gb DECIMAL(10, 2) NULL AFTER vm_cpu_cores,
  ADD COLUMN vm_disk_gb DECIMAL(10, 2) NULL AFTER vm_memory_gb,
  ADD COLUMN vm_storage VARCHAR(255) NULL AFTER vm_disk_gb,
  ADD COLUMN vm_role VARCHAR(255) NULL AFTER vm_storage;
