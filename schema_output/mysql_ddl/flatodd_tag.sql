mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_tag	CREATE TABLE "flatodd_tag" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "name" varchar(150) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "name" ("name")\n)
