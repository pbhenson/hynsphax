create table fax(
	number varchar(128) not null primary key,
	name varchar(1024),
	city varchar(1024),
	state varchar(1024),
	cost int,
	destinations varchar(4096) not null,
	provision_date bigint unsigned,
	hy_job_opts varchar(8192),
	hy_job_opts_in varchar(8192),
	hy_job_opts_out varchar(8192)
);

create table hy_servers(
	hostname varchar(255) not null primary key,
	node_id varchar(2) not null unique key
);

create table ns_servers(
	hostname varchar(255) not null primary key,
	hy_node_order varchar(1024) not null
);

