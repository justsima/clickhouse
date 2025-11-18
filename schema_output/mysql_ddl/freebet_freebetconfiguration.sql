mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
freebet_freebetconfiguration	CREATE TABLE "freebet_freebetconfiguration" (\n  "configuration_ptr_id" int NOT NULL,\n  "bet_bonus_enabled" tinyint(1) NOT NULL,\n  "registeration_bonus_enabled" tinyint(1) NOT NULL,\n  PRIMARY KEY ("configuration_ptr_id"),\n  CONSTRAINT "freebet_freebetconfi_configuration_ptr_id_be890929_fk_flatodd_c" FOREIGN KEY ("configuration_ptr_id") REFERENCES "flatodd_configuration" ("id")\n)
