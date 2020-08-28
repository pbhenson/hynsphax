-- added source_route column as of version x.x
-- for upgrade, run:
--
--   ALTER TABLE fax ADD COLUMN source_route varchar(4096) AFTER destinations;
create table fax(
	number varchar(128) not null primary key,
	name varchar(1024),
	city varchar(1024),
	state varchar(1024),
	cost int,
	destinations varchar(4096) not null,
	source_route varchar(4096),
	provision_date bigint unsigned,
	hy_job_opts text(8192),
	hy_job_opts_in text(8192),
	hy_job_opts_out text(8192)
);

-- added group column/index as of version x.x
-- for upgrade, run:
--
--   ALTER TABLE hy_servers ADD COLUMN hgroup varchar(32) AFTER hostname;
--   ALTER TABLE hy_servers ADD INDEX hs_hgrp (hgroup);
create table hy_servers(
	hostname varchar(255) not null primary key,
	hgroup varchar(32),
	node_id varchar(2) not null unique key,
	index hs_hgrp (hgroup)
);

-- added group column/index as of version x.x
-- for upgrade, run:
--
--   ALTER TABLE ns_servers ADD COLUMN hgroup varchar(32) AFTER hostname;
--   ALTER TABLE ns_servers ADD INDEX hs_hgrp (hgroup);
create table ns_servers(
	hostname varchar(255) not null primary key,
	hgroup varchar(32),
	hy_node_order varchar(1024) not null,
	index ns_hgrp (hgroup)
);

-- new table as of version x.x
create table fb_servers(
	hostname varchar(255) not null primary key,
	hgroup varchar(32),
	index fs_hgrp (hgroup)
);

create table fb_atas(
	mac varchar(12) not null primary key,
	active boolean not null,
	provisioned boolean not null,
	username varchar(128) not null unique key,
	password varchar(128) not null,
	hyns_options varchar(1024),
	ata_options varchar(1024),
	line_options varchar(2048)
);
