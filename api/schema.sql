CREATE TABLE servers (
  id VARCHAR(64) PRIMARY KEY,
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
  status VARCHAR(40) NOT NULL,
  notes TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_servers_renewal_date ON servers (renewal_date);
CREATE INDEX idx_servers_assigned_client ON servers (assigned_client);
