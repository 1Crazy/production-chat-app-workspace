CREATE TABLE "moderation_reports" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "reporter_id" UUID NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" TEXT NOT NULL,
  "conversation_id" UUID,
  "message_id" UUID,
  "reported_user_id" UUID,
  "reason_code" TEXT NOT NULL,
  "description" TEXT,
  "status" TEXT NOT NULL DEFAULT 'pending_review',
  "resolution_note" TEXT,
  "handled_by_user_id" UUID,
  "handled_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "moderation_reports_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "moderation_reports"
ADD CONSTRAINT "moderation_reports_reporter_id_fkey"
FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "moderation_reports_reporter_id_created_at_idx"
ON "moderation_reports"("reporter_id", "created_at");

CREATE INDEX "moderation_reports_target_type_target_id_status_idx"
ON "moderation_reports"("target_type", "target_id", "status");

CREATE INDEX "moderation_reports_status_created_at_idx"
ON "moderation_reports"("status", "created_at");
