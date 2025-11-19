mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
arifpay_depositpaymentmethod	CREATE TABLE "arifpay_depositpaymentmethod" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "name" varchar(200) NOT NULL,\n  "code" varchar(200) NOT NULL,\n  "supports_direct" tinyint(1) NOT NULL,\n  "status" int NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "transaction_fee" double NOT NULL,\n  "url" varchar(200) DEFAULT NULL,\n  "order" int NOT NULL,\n  PRIMARY KEY ("id")\n)
