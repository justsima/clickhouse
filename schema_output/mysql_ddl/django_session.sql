mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
django_session	CREATE TABLE "django_session" (\n  "session_key" varchar(40) NOT NULL,\n  "session_data" longtext NOT NULL,\n  "expire_date" datetime(6) NOT NULL,\n  PRIMARY KEY ("session_key"),\n  KEY "django_session_expire_date_a5c62663" ("expire_date")\n)
