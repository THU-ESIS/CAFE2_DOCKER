USE CAFEWORKER;

DROP TABLE IF EXISTS model_file;
CREATE TABLE model_file LIKE CAFECENTRAL.model_file;

DROP TABLE IF EXISTS deployment;
CREATE TABLE deployment LIKE CAFECENTRAL.deployment;

DROP TABLE IF EXISTS sub_task;
CREATE TABLE sub_task LIKE CAFECENTRAL.sub_task;

DROP TABLE IF EXISTS task;
CREATE TABLE task (
  id INT(10) NOT NULL AUTO_INCREMENT, uuid VARCHAR(64) NOT NULL,
  submition TEXT NOT NULL, create_time DATETIME NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS task_subtask_list;
CREATE TABLE task_subtask_list (
  task_id INT(10) NOT NULL, sub_task_id INT(10) NOT NULL,
  node_id INT(10), PRIMARY KEY (task_id, sub_task_id, node_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS sub_task_result;
CREATE TABLE sub_task_result (
  id INT(10) NOT NULL AUTO_INCREMENT, sub_task_id INT(10) NOT NULL,
  type VARCHAR(16) NOT NULL, path VARCHAR(1024) NOT NULL,
  PRIMARY KEY (id), INDEX idx_sub_task_result_id (sub_task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
