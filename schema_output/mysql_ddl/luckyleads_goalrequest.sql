mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
luckyleads_goalrequest	CREATE TABLE "luckyleads_goalrequest" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "click_id" varchar(36) NOT NULL,\n  "parameters" json DEFAULT NULL,\n  "status" varchar(20) NOT NULL,\n  "value" int DEFAULT NULL,\n  "response" longtext,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "goal" varchar(255) NOT NULL,\n  "transaction_id" varchar(255) DEFAULT NULL,\n  PRIMARY KEY ("id")\n)
