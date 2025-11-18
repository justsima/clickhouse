mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
chappa_bank	CREATE TABLE "chappa_bank" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "name" varchar(200) NOT NULL,\n  "code" varchar(200) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "status" int NOT NULL,\n  "transaction_fee" double NOT NULL,\n  "is_mobile_meny" tinyint(1) NOT NULL,\n  "supports_direct" tinyint(1) NOT NULL,\n  "verification_type" varchar(10) NOT NULL,\n  PRIMARY KEY ("id")\n)
