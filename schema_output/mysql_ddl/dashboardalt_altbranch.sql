mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
dashboardalt_altbranch	CREATE TABLE "dashboardalt_altbranch" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "available_for_report" tinyint(1) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "branch_id" int NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "branch_id" ("branch_id"),\n  CONSTRAINT "dashboardalt_altbranch_branch_id_8b8a7cc5_fk_flatodd_branch_id" FOREIGN KEY ("branch_id") REFERENCES "flatodd_branch" ("id")\n)
