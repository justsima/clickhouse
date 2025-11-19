mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatloyality_loyalitypointwallet	CREATE TABLE "flatloyality_loyalitypointwallet" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "point_balance" double NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "owner_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "owner_id" ("owner_id"),\n  CONSTRAINT "flatloyality_loyalit_owner_id_a986149b_fk_flatodd_m" FOREIGN KEY ("owner_id") REFERENCES "flatodd_member" ("id")\n)
