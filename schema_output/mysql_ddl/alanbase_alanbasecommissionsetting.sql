mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
alanbase_alanbasecommissionsetting	CREATE TABLE "alanbase_alanbasecommissionsetting" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "registration_enabled" tinyint(1) NOT NULL,\n  "casino_ggr_enabled" tinyint(1) NOT NULL,\n  "sportsbook_ggr_enabled" tinyint(1) NOT NULL,\n  "deposit_enabled" tinyint(1) NOT NULL,\n  "first_deposit_enabled" tinyint(1) NOT NULL,\n  PRIMARY KEY ("id")\n)
