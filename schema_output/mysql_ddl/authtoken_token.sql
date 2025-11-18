mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
authtoken_token	CREATE TABLE "authtoken_token" (\n  "key" varchar(40) NOT NULL,\n  "created" datetime(6) NOT NULL,\n  "user_id" int NOT NULL,\n  PRIMARY KEY ("key"),\n  UNIQUE KEY "user_id" ("user_id"),\n  CONSTRAINT "authtoken_token_user_id_35299eff_fk_auth_user_id" FOREIGN KEY ("user_id") REFERENCES "auth_user" ("id")\n)
