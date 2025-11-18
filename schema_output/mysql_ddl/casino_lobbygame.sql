mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_lobbygame	CREATE TABLE "casino_lobbygame" (\n  "id" char(32) NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "updated_at" datetime(6) NOT NULL,\n  "order" int NOT NULL,\n  "game_id" char(32) NOT NULL,\n  PRIMARY KEY ("id"),\n  UNIQUE KEY "game_id" ("game_id"),\n  CONSTRAINT "casino_lobbygame_game_id_ddcb6439_fk_casino_game_id" FOREIGN KEY ("game_id") REFERENCES "casino_game" ("id")\n)
