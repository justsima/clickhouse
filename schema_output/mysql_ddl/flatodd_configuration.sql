mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_configuration	CREATE TABLE "flatodd_configuration" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "config_name" varchar(100) NOT NULL,\n  PRIMARY KEY ("id")\n)
