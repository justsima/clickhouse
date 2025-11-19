mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
freebet_awardrule	CREATE TABLE "freebet_awardrule" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "amount" double NOT NULL,\n  "amount_type" smallint unsigned NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "freebet_awardrule_chk_1" CHECK ((`amount_type` >= 0))\n)
