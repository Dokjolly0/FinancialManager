-- Enables gen_random_uuid(), used as the default for every primary key
-- across the schema (plan.md section 11.1: UUID keys).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
