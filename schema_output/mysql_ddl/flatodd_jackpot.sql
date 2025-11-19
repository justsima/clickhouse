mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_jackpot	CREATE TABLE "flatodd_jackpot" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "start_time" datetime(6) NOT NULL,\n  "end_time" datetime(6) NOT NULL,\n  "stake" double NOT NULL,\n  "possible_win" double NOT NULL,\n  "name" varchar(100) DEFAULT NULL,\n  "is_active" tinyint(1) NOT NULL,\n  PRIMARY KEY ("id")\n)
