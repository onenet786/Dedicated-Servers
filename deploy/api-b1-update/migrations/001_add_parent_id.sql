ALTER TABLE servers ADD COLUMN parent_id VARCHAR(64) NULL AFTER id;
CREATE INDEX idx_servers_parent_id ON servers (parent_id);
