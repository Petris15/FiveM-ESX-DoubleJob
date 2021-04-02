USE `essentialmode`;

ALTER TABLE `users`
	ADD COLUMN `mafiajob` varchar(50) NULL DEFAULT 'nomafia' AFTER `job_grade`,
	ADD COLUMN `mafiajob_grade` INT NULL DEFAULT 0 AFTER `mafiajob`
;

CREATE TABLE `mafiajob_grades` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`mafiajob_name` varchar(50) DEFAULT NULL,
	`mafiagrade` int(11) NOT NULL,
	`name` varchar(50) NOT NULL,
	`label` varchar(50) NOT NULL,
	`salary` int(11) NOT NULL,
	`skin_male` longtext NOT NULL,
	`skin_female` longtext NOT NULL,

	PRIMARY KEY (`id`)
);

INSERT INTO `mafiajob_grades` VALUES (1,'nomafia',0,'nomafia','',0,'{}','{}');

CREATE TABLE `mafiajobs` (
	`name` varchar(50) NOT NULL,
	`label` varchar(50) DEFAULT NULL,

	PRIMARY KEY (`name`)
);

INSERT INTO `mafiajobs` VALUES ('nomafia','');