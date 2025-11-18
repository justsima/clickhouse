mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
kironlite_requestlog	CREATE TABLE "kironlite_requestlog" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "user_token" varchar(150) NOT NULL,\n  "user_id" varchar(150) NOT NULL,\n  "timestamp" datetime(6) NOT NULL,\n  "request_signature" varchar(200) NOT NULL,\n  "request_type" int NOT NULL,\n  "request_reference" varchar(25) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "request_reference" ("request_reference")\n)
