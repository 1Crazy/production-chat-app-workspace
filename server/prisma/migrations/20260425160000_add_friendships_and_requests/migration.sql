CREATE TABLE "friend_requests" (
  "id" TEXT NOT NULL,
  "requester_id" TEXT NOT NULL,
  "addressee_id" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "message" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "responded_at" TIMESTAMP(3),

  CONSTRAINT "friend_requests_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "friendships" (
  "id" TEXT NOT NULL,
  "user_a_id" TEXT NOT NULL,
  "user_b_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "friendships_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "friendships_user_a_id_user_b_id_key"
ON "friendships"("user_a_id", "user_b_id");

CREATE INDEX "friend_requests_requester_id_status_created_at_idx"
ON "friend_requests"("requester_id", "status", "created_at");

CREATE INDEX "friend_requests_addressee_id_status_created_at_idx"
ON "friend_requests"("addressee_id", "status", "created_at");

CREATE INDEX "friend_requests_requester_id_addressee_id_status_idx"
ON "friend_requests"("requester_id", "addressee_id", "status");

CREATE INDEX "friendships_user_a_id_created_at_idx"
ON "friendships"("user_a_id", "created_at");

CREATE INDEX "friendships_user_b_id_created_at_idx"
ON "friendships"("user_b_id", "created_at");

ALTER TABLE "friend_requests"
ADD CONSTRAINT "friend_requests_requester_id_fkey"
FOREIGN KEY ("requester_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "friend_requests"
ADD CONSTRAINT "friend_requests_addressee_id_fkey"
FOREIGN KEY ("addressee_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "friendships"
ADD CONSTRAINT "friendships_user_a_id_fkey"
FOREIGN KEY ("user_a_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "friendships"
ADD CONSTRAINT "friendships_user_b_id_fkey"
FOREIGN KEY ("user_b_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
