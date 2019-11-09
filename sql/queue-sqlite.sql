create table inbound (
	id varchar not null primary key,
	received_time int not null,
	pages int not null,
	cid_from varchar not null,
	cid_to varchar not null,
	destination varchar not null,
	retry_count int not null,
	retry_time int not null
);

create table outbound (
	id varchar not null primary key,
	received_time int not null,
	callback_url varchar not null,
	last_state varchar not null,
	last_status varchar not null
);
