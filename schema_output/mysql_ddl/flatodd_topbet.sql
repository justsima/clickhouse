mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_topbet	CREATE TABLE "flatodd_topbet" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "league_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "flatodd_topbet_league_id_4cbd94fa_fk_flatodd_league_id" ("league_id"),\n  CONSTRAINT "flatodd_topbet_league_id_4cbd94fa_fk_flatodd_league_id" FOREIGN KEY ("league_id") REFERENCES "flatodd_league" ("id")\n)
