mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
client_userimporttasklog	CREATE TABLE "client_userimporttasklog" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "file_name" varchar(200) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "tag_id" int DEFAULT NULL,\n  PRIMARY KEY ("id"),\n  KEY "client_userimporttasklog_tag_id_c866d2ae_fk_flatodd_tag_id" ("tag_id"),\n  CONSTRAINT "client_userimporttasklog_tag_id_c866d2ae_fk_flatodd_tag_id" FOREIGN KEY ("tag_id") REFERENCES "flatodd_tag" ("id")\n)
