mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
auth_group	CREATE TABLE "auth_group" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "name" varchar(150) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "name" ("name")\n)
