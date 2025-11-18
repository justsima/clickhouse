mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_environmentconfig	CREATE TABLE "flatodd_environmentconfig" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "key" varchar(100) NOT NULL,\n  "value" longtext NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "flatodd_environmentconfig_key_d919faf3_uniq" ("key")\n)
