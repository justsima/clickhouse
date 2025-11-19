mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
client_group	CREATE TABLE "client_group" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "name" varchar(100) NOT NULL,\n  "description" longtext NOT NULL,\n  "is_supergroup" tinyint(1) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "name" ("name")\n)
