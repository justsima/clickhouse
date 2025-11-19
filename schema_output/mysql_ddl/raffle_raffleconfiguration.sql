mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
raffle_raffleconfiguration	CREATE TABLE "raffle_raffleconfiguration" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "send_raffle_ticket_generated_sms" tinyint(1) NOT NULL,\n  "game_filter_strategy" varchar(20) NOT NULL,\n  PRIMARY KEY ("id")\n)
