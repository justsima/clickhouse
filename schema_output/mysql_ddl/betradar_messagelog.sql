mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
betradar_messagelog	CREATE TABLE "betradar_messagelog" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "message_type" int NOT NULL,\n  "class_name" varchar(150) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "comment" varchar(150) NOT NULL,\n  "detail_info" longtext NOT NULL,\n  PRIMARY KEY ("id")\n)
