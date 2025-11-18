mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_salesrole	CREATE TABLE "flatodd_salesrole" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "role" int NOT NULL,\n  "sales_id" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "flatodd_salesrole_sales_id_role_12d6442f_uniq" ("sales_id","role"),\n  CONSTRAINT "flatodd_salesrole_sales_id_297518da_fk_flatodd_sales_id" FOREIGN KEY ("sales_id") REFERENCES "flatodd_sales" ("id")\n)
