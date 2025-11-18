mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
smsbet_statestore	CREATE TABLE "smsbet_statestore" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "useridentifier" varchar(100) NOT NULL,\n  "curstage" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "state_name" varchar(100) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "smsbet_statestore_useridentifier_state_name_6b2cda7e_uniq" ("useridentifier","state_name")\n)
