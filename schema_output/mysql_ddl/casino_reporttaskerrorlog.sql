mysql: [Warning] Using a password on the command line interface can be insecure.
Table	Create Table
casino_reporttaskerrorlog	CREATE TABLE "casino_reporttaskerrorlog" (\n  "id" bigint NOT NULL AUTO_INCREMENT,\n  "error_message" longtext NOT NULL,\n  "created_at" datetime(6) NOT NULL,\n  "task_id" bigint NOT NULL,\n  PRIMARY KEY ("id"),\n  KEY "casino_reporttaskerr_task_id_3e6374c7_fk_casino_re" ("task_id"),\n  CONSTRAINT "casino_reporttaskerr_task_id_3e6374c7_fk_casino_re" FOREIGN KEY ("task_id") REFERENCES "casino_reporttask" ("id")\n)
