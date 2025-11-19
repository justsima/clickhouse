mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_promotiondescription	CREATE TABLE "flatodd_promotiondescription" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "bonus_type" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "description" longtext NOT NULL,\n  "title" varchar(150) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "thumbnail" varchar(100) DEFAULT NULL,\n  PRIMARY KEY ("id")\n)
