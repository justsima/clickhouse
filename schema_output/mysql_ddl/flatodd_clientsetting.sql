mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_clientsetting	CREATE TABLE "flatodd_clientsetting" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "cancel_window" int NOT NULL,\n  "registeration_enabled" tinyint(1) NOT NULL,\n  "deposit_enabled" tinyint(1) NOT NULL,\n  "withdrawal_enabled" tinyint(1) NOT NULL,\n  "show_event_from" int DEFAULT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "online_minimum_stake" int DEFAULT NULL,\n  PRIMARY KEY ("id")\n)
