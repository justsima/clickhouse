mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
emola_emolaconfiguration	CREATE TABLE "emola_emolaconfiguration" (\n  "configuration_ptr_id" int NOT NULL,\n  "base_url" varchar(200) NOT NULL,\n  "partner_code" varchar(50) NOT NULL,\n  "partner_key" varchar(50) NOT NULL,\n  "username" varchar(50) NOT NULL,\n  "password" varchar(50) NOT NULL,\n  PRIMARY KEY ("configuration_ptr_id"),\n  CONSTRAINT "emola_emolaconfigura_configuration_ptr_id_a61dcdc0_fk_flatodd_c" FOREIGN KEY ("configuration_ptr_id") REFERENCES "flatodd_configuration" ("id")\n)
