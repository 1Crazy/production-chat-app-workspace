DO
$$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'chat_dev') THEN
    CREATE ROLE chat_dev LOGIN PASSWORD 'chat_dev';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'chat_test') THEN
    CREATE ROLE chat_test LOGIN PASSWORD 'chat_test';
  END IF;
END
$$;

SELECT 'CREATE DATABASE chat_dev OWNER chat_dev'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'chat_dev')\gexec

SELECT 'CREATE DATABASE chat_test OWNER chat_test'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'chat_test')\gexec
