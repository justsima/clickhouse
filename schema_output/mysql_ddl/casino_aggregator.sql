mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_aggregator	CREATE TABLE "casino_aggregator" (\n  "id" char(32) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "name" varchar(100) NOT NULL,\n  "idn" varchar(50) NOT NULL,\n  "description" longtext NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "name" ("name"),\n  UNIQUE KEY "idn" ("idn"),\n  KEY "casino_aggr_created_698eed_idx" ("created_at")\n)
