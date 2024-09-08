#!bin/bash

podman run -d -p "5432:5432" -v ./postgres-data:/var/lib/postgresql/data --name analytics-postgres -e POSTGRES_PASSWORD=${PG_PWD} -e POSTGRES_USERNAME=${PG_USER} -e POSTGRES_DB="analytics" postgres
