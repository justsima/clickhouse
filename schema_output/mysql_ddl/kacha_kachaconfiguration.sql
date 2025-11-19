mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
kacha_kachaconfiguration	CREATE TABLE "kacha_kachaconfiguration" (\n  "configuration_ptr_id" int NOT NULL,\n  "shortcode" varchar(150) NOT NULL,\n  "password" varchar(150) NOT NULL,\n  "username" varchar(150) NOT NULL,\n  "base_url" varchar(200) NOT NULL,\n  PRIMARY KEY ("configuration_ptr_id"),\n  CONSTRAINT "kacha_kachaconfigura_configuration_ptr_id_5ae909ff_fk_flatodd_c" FOREIGN KEY ("configuration_ptr_id") REFERENCES "flatodd_configuration" ("id")\n)
