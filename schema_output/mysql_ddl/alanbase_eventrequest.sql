mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
alanbase_eventrequest	CREATE TABLE "alanbase_eventrequest" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "click_id" varchar(36) NOT NULL,\n  "parameters" json DEFAULT NULL,\n  "status" varchar(20) NOT NULL,\n  "value" int DEFAULT NULL,\n  "response" longtext,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "event" varchar(255) NOT NULL,\n  PRIMARY KEY ("id")\n)
