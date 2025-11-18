mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_contentservercategory	CREATE TABLE "casino_contentservercategory" (\n  "id" char(32) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "name" varchar(100) NOT NULL,\n  "description" longtext NOT NULL,\n  "logo" varchar(200) DEFAULT NULL,\n  "order" int NOT NULL,\n  "enabled" tinyint(1) NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "casino_cont_created_d270d2_idx" ("created_at")\n)
