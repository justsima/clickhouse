mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_freebetconfiguration	CREATE TABLE "casino_freebetconfiguration" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "max_payout_amount" decimal(10,2) NOT NULL,\n  "provider_id" char(32) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "provider_id" ("provider_id"),\n  KEY "casino_free_provide_cf26fa_idx" ("provider_id"),\n  CONSTRAINT "casino_freebetconfig_provider_id_ad8490ee_fk_casino_ga" FOREIGN KEY ("provider_id") REFERENCES "casino_gameprovider" ("id")\n)
