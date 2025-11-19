mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_withdrawrequest	CREATE TABLE "flatodd_withdrawrequest" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "code" varchar(100) DEFAULT NULL,\n  "amount" double NOT NULL,\n  "member_id" int NOT NULL,\n  "created_on" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "member_id" ("member_id"),\n  CONSTRAINT "flatodd_withdrawrequest_member_id_4cf7593f_fk_flatodd_member_id" FOREIGN KEY ("member_id") REFERENCES "flatodd_member" ("id")\n)
