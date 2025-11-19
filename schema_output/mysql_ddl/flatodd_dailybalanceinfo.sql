mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_dailybalanceinfo	CREATE TABLE "flatodd_dailybalanceinfo" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "balance" double NOT NULL,\n  "created_on" date NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id")\n)
