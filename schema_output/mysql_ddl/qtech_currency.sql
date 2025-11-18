mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
qtech_currency	CREATE TABLE "qtech_currency" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "name" varchar(150) NOT NULL,\n  "code" varchar(5) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "is_supported" tinyint(1) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "qtech_currency_code_b24c7e45_uniq" ("code")\n)
