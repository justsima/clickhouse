mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
betradar_cacheloginfo	CREATE TABLE "betradar_cacheloginfo" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "cache_type" smallint unsigned NOT NULL,\n  "completed_at" datetime(6) DEFAULT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "processing_rate" smallint unsigned NOT NULL,\n  PRIMARY KEY ("id"),\n  CONSTRAINT "betradar_cacheloginfo_chk_1" CHECK ((`cache_type` >= 0)),\n  CONSTRAINT "betradar_cacheloginfo_chk_2" CHECK ((`processing_rate` >= 0))\n)
