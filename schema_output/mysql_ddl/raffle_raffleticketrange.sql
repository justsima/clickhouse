mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
raffle_raffleticketrange	CREATE TABLE "raffle_raffleticketrange" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "event_type" varchar(20) NOT NULL,\n  "min_amount" decimal(10,2) NOT NULL,\n  "max_amount" decimal(10,2) DEFAULT NULL,\n  "ticket_count" int unsigned NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "raffle_raffleticketrange_chk_1" CHECK ((`ticket_count` >= 0))\n)
