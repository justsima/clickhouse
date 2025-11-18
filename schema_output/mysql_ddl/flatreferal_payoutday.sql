mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatreferal_payoutday	CREATE TABLE "flatreferal_payoutday" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "recurrence" varchar(20) NOT NULL,\n  "custom_date" int DEFAULT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id")\n)
