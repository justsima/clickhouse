mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_agentrole	CREATE TABLE "flatodd_agentrole" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "role" int NOT NULL,\n  "agent_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "flatodd_agentrole_agent_id_role_3a3f1e5d_uniq" ("agent_id","role"),\n  CONSTRAINT "flatodd_agentrole_agent_id_ff77d881_fk_flatodd_agent_id" FOREIGN KEY ("agent_id") REFERENCES "flatodd_agent" ("id")\n)
