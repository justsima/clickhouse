mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_levydatablock	CREATE TABLE "flatodd_levydatablock" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "month" int NOT NULL,\n  "year" int NOT NULL,\n  "percentage" decimal(5,4) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "flatodd_levydatablock_month_year_d6404da9_uniq" ("month","year")\n)
