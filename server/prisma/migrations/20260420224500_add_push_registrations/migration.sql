CREATE TABLE "push_registrations" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "session_id" TEXT NOT NULL,
  "provider" TEXT NOT NULL,
  "token" TEXT NOT NULL,
  "push_environment" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "last_registered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "revoked_at" TIMESTAMP(3),

  CONSTRAINT "push_registrations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "push_registrations_provider_token_key"
ON "push_registrations"("provider", "token");

CREATE INDEX "push_registrations_session_id_provider_revoked_at_idx"
ON "push_registrations"("session_id", "provider", "revoked_at");

CREATE INDEX "push_registrations_user_id_revoked_at_updated_at_idx"
ON "push_registrations"("user_id", "revoked_at", "updated_at");

ALTER TABLE "push_registrations"
ADD CONSTRAINT "push_registrations_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "push_registrations"
ADD CONSTRAINT "push_registrations_session_id_fkey"
FOREIGN KEY ("session_id") REFERENCES "device_sessions"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
