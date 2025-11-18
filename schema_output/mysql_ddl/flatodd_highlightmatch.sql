mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_highlightmatch	CREATE TABLE "flatodd_highlightmatch" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "match_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "match_id" ("match_id"),\n  CONSTRAINT "flatodd_highlightmatch_match_id_c08f8b50_fk_flatodd_match_id" FOREIGN KEY ("match_id") REFERENCES "flatodd_match" ("id")\n)
