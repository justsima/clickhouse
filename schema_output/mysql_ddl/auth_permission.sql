mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
auth_permission	CREATE TABLE "auth_permission" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "name" varchar(255) NOT NULL,\n  "content_type_id" int NOT NULL,\n  "codename" varchar(100) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "auth_permission_content_type_id_codename_01ab375a_uniq" ("content_type_id","codename"),\n  CONSTRAINT "auth_permission_content_type_id_2f476e4b_fk_django_co" FOREIGN KEY ("content_type_id") REFERENCES "django_content_type" ("id")\n)
