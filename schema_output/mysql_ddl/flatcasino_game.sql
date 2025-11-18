mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
flatcasino_game	CREATE TABLE "flatcasino_game" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "game_id" varchar(100) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  PRIMARY KEY ("id")\n)
