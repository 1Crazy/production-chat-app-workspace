ALTER TABLE "users"
ADD COLUMN "password_hash" TEXT,
ADD COLUMN "password_updated_at" TIMESTAMP(3);

ALTER TABLE "verification_codes"
ADD COLUMN "purpose" TEXT NOT NULL DEFAULT 'register';

ALTER TABLE "verification_codes"
DROP CONSTRAINT "verification_codes_pkey";

ALTER TABLE "verification_codes"
ADD CONSTRAINT "verification_codes_pkey" PRIMARY KEY ("identifier", "purpose");

ALTER TABLE "verification_codes"
ALTER COLUMN "purpose" DROP DEFAULT;
