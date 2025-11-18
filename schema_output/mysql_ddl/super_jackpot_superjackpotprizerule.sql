mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
super_jackpot_superjackpotprizerule	CREATE TABLE "super_jackpot_superjackpotprizerule" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "title" varchar(255) NOT NULL,\n  "rule" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "rule" ("rule")\n)
