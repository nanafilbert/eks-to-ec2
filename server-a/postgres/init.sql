-- Runs once on first container start
-- UUID support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Fuzzy text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
-- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS "citext";

SET timezone = 'UTC';
