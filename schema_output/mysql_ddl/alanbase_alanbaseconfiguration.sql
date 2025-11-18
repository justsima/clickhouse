mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
alanbase_alanbaseconfiguration	CREATE TABLE "alanbase_alanbaseconfiguration" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "api_key" varchar(255) DEFAULT NULL,\n  "base_url" varchar(200) DEFAULT NULL,\n  "goal_path" varchar(255) DEFAULT NULL,\n  "event_path" varchar(255) DEFAULT NULL,\n  PRIMARY KEY ("id")\n)
