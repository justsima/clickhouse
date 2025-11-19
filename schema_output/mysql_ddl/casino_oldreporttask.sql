mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_oldreporttask	CREATE TABLE "casino_oldreporttask" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "type" varchar(100) NOT NULL,\n  "year" int NOT NULL,\n  "month" int NOT NULL,\n  "status" varchar(100) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "completed_at" datetime(6) DEFAULT NULL,\n  "error_message" longtext,\n  PRIMARY KEY ("id")\n)
