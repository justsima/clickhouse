mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
genius_sport_geniussportmatch	CREATE TABLE "genius_sport_geniussportmatch" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "match_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "match_id" ("match_id"),\n  CONSTRAINT "genius_sport_geniuss_match_id_bfbb9a36_fk_flatodd_m" FOREIGN KEY ("match_id") REFERENCES "flatodd_match" ("id")\n)
