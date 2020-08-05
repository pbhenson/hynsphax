
create table fb_inbound_queue(
	fb_id varchar(36) not null primary key,
	fb_username varchar(128) not null,
	fb_ata_mac varchar(12) not null,
	hy_node_id varchar(2) not null,
	hy_queue_id int unsigned not null,
	from_number varchar(128) not null,
	to_number varchar(128) not null,
	retries int unsigned,
	status int unsigned,
	message varchar(256),
	pages int unsigned not null,
	hy_received_time datetime not null,
	hy_sent_time datetime,
	fb_report_time datetime,
	delivered boolean,
	routing_history text,
	index fbiq_hrt (hy_received_time)
);

create table fb_outbound_queue(
	fb_id varchar(36) not null primary key,
	fb_username varchar(128) not null,
	fb_ata_mac varchar(12) not null,
	hy_node_id varchar(2) not null,
	hy_queue_id int unsigned not null,
	from_number varchar(128) not null,
	to_number varchar(128) not null,
	retries int unsigned,
	status int unsigned,
	message varchar(256),
	pages int unsigned,
	hy_received_time datetime not null,
	hy_sent_time datetime,
	state varchar(10),
	index fboq_hrt (hy_received_time)
);
