CREATE TABLE servers (
  id VARCHAR(64) PRIMARY KEY,
  parent_id VARCHAR(64) NULL,
  name VARCHAR(255) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  provider VARCHAR(255) NOT NULL,
  location VARCHAR(255) NOT NULL,
  specification TEXT NOT NULL,
  operating_system VARCHAR(255) NOT NULL,
  login_user VARCHAR(255) NOT NULL,
  monthly_cost DECIMAL(10, 2) NOT NULL,
  purchase_date VARCHAR(40) NOT NULL,
  renewal_date VARCHAR(40) NOT NULL,
  assigned_client VARCHAR(255) NOT NULL,
  client_phone VARCHAR(40) NOT NULL DEFAULT '',
  status VARCHAR(40) NOT NULL,
  notes TEXT NOT NULL,
  vm_cpu_cores INT NULL,
  vm_memory_gb DECIMAL(10, 2) NULL,
  vm_disk_gb DECIMAL(10, 2) NULL,
  vm_storage VARCHAR(255) NULL,
  vm_role VARCHAR(255) NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_servers_parent_id ON servers (parent_id);
CREATE INDEX idx_servers_renewal_date ON servers (renewal_date);
CREATE INDEX idx_servers_assigned_client ON servers (assigned_client);

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
);
