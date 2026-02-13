-- Initialize Metabase application database
-- Note: This is already run via k8s/postgres/configmap-init.yaml
-- This script is for manual execution or reference

-- Create Metabase application database (if not exists)
SELECT 'CREATE DATABASE metabase_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase_app')\gexec

-- Grant access to the current user
GRANT ALL PRIVILEGES ON DATABASE metabase_app TO CURRENT_USER;
