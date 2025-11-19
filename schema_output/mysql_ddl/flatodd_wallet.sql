mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_wallet	CREATE TABLE "flatodd_wallet" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "balance" double NOT NULL,\n  "is_active" tinyint(1) NOT NULL,\n  "owner_id" int NOT NULL,\n  "payable" double NOT NULL,\n  "nonwithdrawable" double NOT NULL,\n  "last_wallet_changed_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "owner_id" ("owner_id"),\n  CONSTRAINT "flatodd_wallet_owner_id_7025fbba_fk_flatodd_member_id" FOREIGN KEY ("owner_id") REFERENCES "flatodd_member" ("id")\n)
