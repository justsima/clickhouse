mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
cms_ug_game	CREATE TABLE "cms_ug_game" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "name" varchar(100) NOT NULL,\n  "game_id" varchar(100) NOT NULL,\n  "category" varchar(20) NOT NULL,\n  "game_type" varchar(20) NOT NULL,\n  "game_variant" varchar(20) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "cms_ug_game_game_id_category_game_ty_8eb7ad36_uniq" ("game_id","category","game_type","game_variant")\n)
