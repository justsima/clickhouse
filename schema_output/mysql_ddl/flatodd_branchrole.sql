mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_branchrole	CREATE TABLE "flatodd_branchrole" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "role" int NOT NULL,\n  "branch_id" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "flatodd_branchrole_branch_id_cc260ebd_fk_flatodd_branch_id" ("branch_id"),\n  CONSTRAINT "flatodd_branchrole_branch_id_cc260ebd_fk_flatodd_branch_id" FOREIGN KEY ("branch_id") REFERENCES "flatodd_branch" ("id")\n)
