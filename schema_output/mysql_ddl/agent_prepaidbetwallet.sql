mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
agent_prepaidbetwallet	CREATE TABLE "agent_prepaidbetwallet" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "balance" double NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "agent_id" int NOT NULL,\n  "credit_limit" double NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "agent_id" ("agent_id"),\n  CONSTRAINT "agent_prepaidbetwallet_agent_id_31193453_fk_flatodd_agent_id" FOREIGN KEY ("agent_id") REFERENCES "flatodd_agent" ("id")\n)
