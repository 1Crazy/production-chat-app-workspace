CREATE TABLE "admin_audit_logs" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "actor_user_id" UUID,
  "action" TEXT NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" TEXT NOT NULL,
  "result" TEXT NOT NULL,
  "summary" TEXT NOT NULL,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "admin_audit_logs_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "admin_audit_logs"
ADD CONSTRAINT "admin_audit_logs_actor_user_id_fkey"
FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "admin_audit_logs_actor_user_id_created_at_idx"
ON "admin_audit_logs"("actor_user_id", "created_at");

CREATE INDEX "admin_audit_logs_action_created_at_idx"
ON "admin_audit_logs"("action", "created_at");

CREATE INDEX "admin_audit_logs_target_type_target_id_created_at_idx"
ON "admin_audit_logs"("target_type", "target_id", "created_at");
