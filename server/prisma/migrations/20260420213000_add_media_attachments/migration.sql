CREATE TABLE "media_attachments" (
  "id" TEXT NOT NULL,
  "owner_id" TEXT NOT NULL,
  "conversation_id" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "attachment_kind" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending_upload',
  "object_key" TEXT NOT NULL,
  "file_name" TEXT NOT NULL,
  "mime_type" TEXT NOT NULL,
  "size_bytes" INTEGER NOT NULL,
  "preview_object_key" TEXT,
  "failure_reason" TEXT,
  "uploaded_at" TIMESTAMP(3),
  "confirmed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "media_attachments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "media_attachments_object_key_key"
ON "media_attachments"("object_key");

CREATE INDEX "media_attachments_conversation_id_status_created_at_idx"
ON "media_attachments"("conversation_id", "status", "created_at");

CREATE INDEX "media_attachments_owner_id_created_at_idx"
ON "media_attachments"("owner_id", "created_at");

ALTER TABLE "media_attachments"
ADD CONSTRAINT "media_attachments_owner_id_fkey"
FOREIGN KEY ("owner_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "media_attachments"
ADD CONSTRAINT "media_attachments_conversation_id_fkey"
FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
