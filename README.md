# POSTGRES+DUCKDB analytics side project

I am using postgres + duckdb plugin and go to create a simple analytics side project.

## Why?

I want to learn more about how to use postgres and duckdb to create a simple analytics side project.

## How?

I will use the following tools:

* Postgres on raspberry pi
* Duckdb plugin for postgres
* Go for the backend
* sqlmesh for any data transformation and views
* metabase for the frontend

### Using DuckDB with Postgres

These are the [docs](https://github.com/duckdb/pg_duckdb/tree/main/docs) for the docker image I am using. We are just pulling the data from api and sending it to the database. We are using the public schema which should be equiped with the duckdb plugin.

### Migrations

We are using [goose]()for migrations. They are run at startup of the go app. The migrations are stored in the `persistance/postgres/migrations` folder.

## What?

This is what we want to do:
11/21/24

* [x] Create a postgres database with the duckdb plugin

12/6/24

* [x] Create a go project that connects to the twitch api and gets the analytics of a streamer
* [x] connect go app to the postgres database
* [ ] send the data to the database

Future:

* [ ] Create a sqlmesh project that transforms the data
* [ ] Create a metabase project that connects to the database
* [ ] Connect youtube api to the go app
* [ ] Conncet bluesky api to the go app
* [ ] Connect twitter api to the go app
* [ ] Connect discord api to the go app
* [ ] Connect instagram api to the go app
* [ ] Connect tiktok api to the go app
