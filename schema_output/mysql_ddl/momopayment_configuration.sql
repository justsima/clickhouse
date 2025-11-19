mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
momopayment_configuration	CREATE TABLE "momopayment_configuration" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "key" varchar(150) NOT NULL,\n  "value" longtext NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "key" ("key")\n)
