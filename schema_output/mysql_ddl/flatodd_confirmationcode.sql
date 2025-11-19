mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_confirmationcode	CREATE TABLE "flatodd_confirmationcode" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "code" varchar(10) NOT NULL,\n  "member_id" int NOT NULL,\n  "attempt" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "member_id" ("member_id"),\n  CONSTRAINT "flatodd_confirmationcode_member_id_8d6509ac_fk_flatodd_member_id" FOREIGN KEY ("member_id") REFERENCES "flatodd_member" ("id")\n)
