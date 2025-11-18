mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
freebet_rule	CREATE TABLE "freebet_rule" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "expire_upto" datetime(6) DEFAULT NULL,\n  "expire_within" int DEFAULT NULL,\n  "period_type" int NOT NULL,\n  "status" smallint unsigned NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "freebet_rule_chk_1" CHECK ((`status` >= 0))\n)
