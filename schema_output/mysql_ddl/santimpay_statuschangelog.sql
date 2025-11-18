mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
santimpay_statuschangelog	CREATE TABLE "santimpay_statuschangelog" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "status" smallint unsigned NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "santimpay_statuschangelog_chk_1" CHECK ((`status` >= 0))\n)
