CREATE TABLE "conversations" (
  "id" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "title" TEXT,
  "created_by" TEXT NOT NULL,
  "direct_key" TEXT,
  "latest_sequence" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "conversations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "conversation_members" (
  "id" TEXT NOT NULL,
  "conversation_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "conversation_members_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "messages" (
  "id" TEXT NOT NULL,
  "conversation_id" TEXT NOT NULL,
  "sender_id" TEXT NOT NULL,
  "client_message_id" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "sequence" INTEGER NOT NULL,
  "content" JSONB NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "read_cursors" (
  "id" TEXT NOT NULL,
  "conversation_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "last_read_sequence" INTEGER NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "read_cursors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "conversations_direct_key_key"
ON "conversations"("direct_key");

CREATE INDEX "conversations_created_by_updated_at_idx"
ON "conversations"("created_by", "updated_at");

CREATE INDEX "conversations_updated_at_idx"
ON "conversations"("updated_at");

CREATE UNIQUE INDEX "conversation_members_conversation_id_user_id_key"
ON "conversation_members"("conversation_id", "user_id");

CREATE INDEX "conversation_members_user_id_joined_at_idx"
ON "conversation_members"("user_id", "joined_at");

CREATE UNIQUE INDEX "messages_conversation_id_sequence_key"
ON "messages"("conversation_id", "sequence");

CREATE UNIQUE INDEX "messages_conversation_id_sender_id_client_message_id_key"
ON "messages"("conversation_id", "sender_id", "client_message_id");

CREATE INDEX "messages_conversation_id_created_at_idx"
ON "messages"("conversation_id", "created_at");

CREATE INDEX "messages_sender_id_created_at_idx"
ON "messages"("sender_id", "created_at");

CREATE UNIQUE INDEX "read_cursors_conversation_id_user_id_key"
ON "read_cursors"("conversation_id", "user_id");

CREATE INDEX "read_cursors_user_id_updated_at_idx"
ON "read_cursors"("user_id", "updated_at");

ALTER TABLE "conversations"
ADD CONSTRAINT "conversations_created_by_fkey"
FOREIGN KEY ("created_by") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "conversation_members"
ADD CONSTRAINT "conversation_members_conversation_id_fkey"
FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "conversation_members"
ADD CONSTRAINT "conversation_members_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "messages"
ADD CONSTRAINT "messages_conversation_id_fkey"
FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "messages"
ADD CONSTRAINT "messages_sender_id_fkey"
FOREIGN KEY ("sender_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "read_cursors"
ADD CONSTRAINT "read_cursors_conversation_id_fkey"
FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "read_cursors"
ADD CONSTRAINT "read_cursors_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
