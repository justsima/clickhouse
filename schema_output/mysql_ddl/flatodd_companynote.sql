mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatodd_companynote	CREATE TABLE "flatodd_companynote" (\n  "id" int NOT NULL AUTO_INCREMENT,\n  "note_type" varchar(13) NOT NULL,\n  "note" longtext NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "locale_id" int DEFAULT NULL,\n  PRIMARY KEY ("id"),\n  KEY "flatodd_companynote_locale_id_9c571e25_fk_flatodd_langlocale_id" ("locale_id"),\n  CONSTRAINT "flatodd_companynote_locale_id_9c571e25_fk_flatodd_langlocale_id" FOREIGN KEY ("locale_id") REFERENCES "flatodd_langlocale" ("id")\n)
