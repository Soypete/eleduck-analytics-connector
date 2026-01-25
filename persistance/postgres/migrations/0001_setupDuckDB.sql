-- +goose Up
create table if not exists streams (
	uuid uuid primary key default gen_random_uuid(),
	source text not null,
	source_id text not null unique,
	user_id text not null,
	user_login text not null,
	user_name text,
	game_id text not null, 
	game_name text not null,
	category text not null,
	title text not null,
	started_at timestamptz not null,
	language text not null,
	thumbnail_url text ,
	tag_ids text[],
	tags text[],
	is_mature boolean
);

create index if not exists streams_source_id on streams(source_id);

-- viewer count at a point in time
create table if not exists stream_view_count (
	stream_id uuid references streams(uuid),
	viewer_count int not null,
	time_stamp timestamptz not null
);

-- +goose Down
drop table if exists streams CASCADE;
drop table if exists stream_view_count;
