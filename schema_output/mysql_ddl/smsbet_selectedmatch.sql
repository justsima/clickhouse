mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
smsbet_selectedmatch	CREATE TABLE "smsbet_selectedmatch" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "created_at" datetime(6) NOT NULL,\n  "match_id" int NOT NULL,\n  "priority" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "smsbet_selectedmatch_match_id_94f8f598_uniq" ("match_id"),\n  CONSTRAINT "smsbet_selectedmatch_match_id_94f8f598_fk_flatodd_match_id" FOREIGN KEY ("match_id") REFERENCES "flatodd_match" ("id")\n)
