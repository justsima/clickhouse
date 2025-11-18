mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_wallettemplog	CREATE TABLE "flatodd_wallettemplog" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "amount" double NOT NULL,\n  "log_tex" varchar(150) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "wallet_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "flatodd_wallettemplog_wallet_id_f4edcafe_fk_flatodd_wallet_id" ("wallet_id"),\n  CONSTRAINT "flatodd_wallettemplog_wallet_id_f4edcafe_fk_flatodd_wallet_id" FOREIGN KEY ("wallet_id") REFERENCES "flatodd_wallet" ("id")\n)
