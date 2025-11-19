mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_langlocale	CREATE TABLE "flatodd_langlocale" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "name" varchar(150) NOT NULL,\n  "shortcode" varchar(10) NOT NULL,\n  "logo" varchar(100) DEFAULT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "shortcode" ("shortcode")\n)
