mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
smsbet_messagelog	CREATE TABLE "smsbet_messagelog" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "messageid" varchar(100) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "smsbet_messagelog_messageid_4d0cc676" ("messageid")\n)
