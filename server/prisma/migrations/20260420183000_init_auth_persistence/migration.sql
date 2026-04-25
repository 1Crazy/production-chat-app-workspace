CREATE TABLE "users" (
  "id" TEXT NOT NULL,
  "identifier" TEXT NOT NULL,
  "nickname" TEXT NOT NULL,
  "handle" TEXT NOT NULL,
  "avatar_url" TEXT,
  "discovery_mode" TEXT NOT NULL DEFAULT 'public',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "disabled_at" TIMESTAMP(3),

  CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "verification_codes" (
  "identifier" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "consumed_at" TIMESTAMP(3),

  CONSTRAINT "verification_codes_pkey" PRIMARY KEY ("identifier")
);

CREATE TABLE "device_sessions" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "device_name" TEXT NOT NULL,
  "refresh_nonce" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "revoked_at" TIMESTAMP(3),

  CONSTRAINT "device_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_identifier_key" ON "users"("identifier");
CREATE UNIQUE INDEX "users_handle_key" ON "users"("handle");
CREATE INDEX "device_sessions_user_id_revoked_at_last_seen_at_idx"
ON "device_sessions"("user_id", "revoked_at", "last_seen_at");

ALTER TABLE "device_sessions"
ADD CONSTRAINT "device_sessions_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
