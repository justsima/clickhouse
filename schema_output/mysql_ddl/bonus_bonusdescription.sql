mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
bonus_bonusdescription	CREATE TABLE "bonus_bonusdescription" (\n  "id" char(32) NOT NULL,\n  "name" varchar(100) NOT NULL,\n  "short_description" varchar(250) NOT NULL,\n  "long_description" longtext NOT NULL,\n  "status" smallint unsigned NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "bonus_bonusdescription_chk_1" CHECK ((`status` >= 0))\n)
