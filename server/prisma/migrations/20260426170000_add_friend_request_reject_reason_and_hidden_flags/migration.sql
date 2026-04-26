ALTER TABLE "friend_requests"
ADD COLUMN "reject_reason" TEXT,
ADD COLUMN "hidden_by_requester_at" TIMESTAMP(3),
ADD COLUMN "hidden_by_addressee_at" TIMESTAMP(3);
