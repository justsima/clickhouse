mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_streaksetting	CREATE TABLE "flatodd_streaksetting" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "deposit" tinyint(1) NOT NULL,\n  "withdrawal" tinyint(1) NOT NULL,\n  "sport_bet" tinyint(1) NOT NULL,\n  "casino_bet" tinyint(1) NOT NULL,\n  "streak_weight" int NOT NULL,\n  "description" longtext,\n  PRIMARY KEY ("id")\n)
