mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
client_affiliateupdatelog	CREATE TABLE "client_affiliateupdatelog" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "affected_member_ids" json NOT NULL,\n  "affiliate_id" varchar(255) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "client_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "client_affiliateupda_client_id_d1217392_fk_flatodd_c" ("client_id"),\n  CONSTRAINT "client_affiliateupda_client_id_d1217392_fk_flatodd_c" FOREIGN KEY ("client_id") REFERENCES "flatodd_client" ("id")\n)
