-- PREPARED ONLY. Requires separate Part B.2 execution approval and target verification.
-- No password, LOGIN activation, ownership transfer or role membership is provisioned.
BEGIN;
SET LOCAL statement_timeout = '10s';
SET LOCAL lock_timeout = '5s';

DO $preflight$
BEGIN
  IF current_user <> 'postgres' OR current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'Expected controlled owner connection; abort';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'sellio_runtime') THEN
    RAISE EXCEPTION 'Runtime role already exists; inspect it instead of overwriting it';
  END IF;
  IF (SELECT count(*) FROM public._prisma_migrations) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM public._prisma_migrations
       WHERE migration_name = '20261120000000_initial'
         AND checksum = '00e9084376d3d894acd2575dcc5999db2286b206b5eafd297a49cae35a5515b6'
         AND finished_at IS NOT NULL AND rolled_back_at IS NULL
     ) THEN
    RAISE EXCEPTION 'Unexpected migration baseline; abort';
  END IF;
END;
$preflight$;

CREATE ROLE sellio_runtime
  NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS;

COMMIT;
