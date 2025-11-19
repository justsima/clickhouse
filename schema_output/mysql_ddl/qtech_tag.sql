mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
qtech_tag	CREATE TABLE "qtech_tag" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "name" varchar(150) NOT NULL,\n  "order" int NOT NULL,\n  "logo" varchar(100) DEFAULT NULL,\n  "is_shown_on_lobby" tinyint(1) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "status" smallint unsigned NOT NULL,\n  "phone_template" varchar(30) NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "qtech_tag_chk_1" CHECK ((`status` >= 0))\n)
