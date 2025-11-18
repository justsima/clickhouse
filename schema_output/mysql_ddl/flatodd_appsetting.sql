mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_appsetting	CREATE TABLE "flatodd_appsetting" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "hookToken" varchar(200) NOT NULL,\n  "feedDomain" varchar(200) NOT NULL,\n  "apiKey" varchar(200) NOT NULL,\n  PRIMARY KEY ("id")\n)
