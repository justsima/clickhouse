mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_topmatch	CREATE TABLE "flatodd_topmatch" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "match_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "match_id" ("match_id"),\n  CONSTRAINT "flatodd_topmatch_match_id_6c045c60_fk_flatodd_match_id" FOREIGN KEY ("match_id") REFERENCES "flatodd_match" ("id")\n)
