mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_clientrole	CREATE TABLE "flatodd_clientrole" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "role" int NOT NULL,\n  "client_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "flatodd_clientrole_client_id_e084b96f_fk_flatodd_client_id" ("client_id"),\n  CONSTRAINT "flatodd_clientrole_client_id_e084b96f_fk_flatodd_client_id" FOREIGN KEY ("client_id") REFERENCES "flatodd_client" ("id")\n)
