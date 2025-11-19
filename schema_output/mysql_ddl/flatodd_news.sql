mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_news	CREATE TABLE "flatodd_news" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "title" varchar(200) NOT NULL,\n  "description" longtext NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id")\n)
