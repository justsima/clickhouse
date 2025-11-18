mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_usertype	CREATE TABLE "flatodd_usertype" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "user_type" int NOT NULL,\n  "user_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "user_id" ("user_id"),\n  CONSTRAINT "flatodd_usertype_user_id_647e02e1_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")\n)
