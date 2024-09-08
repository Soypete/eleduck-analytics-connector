FROM ubuntu:22.04 as builder

# Install the required packages
RUN apt update && export DEBIAN_FRONTEND=noninteractive && apt install -y git g++ cmake ninja-build
# Clone the duckdb repository
RUN git clone --depth=1 https://github.com/duckdb/duckdb.git
RUN cd duckdb && GEN=ninja make

ENTRYPOINT ["duckdb"]

#
# RUN git clone https://github.com/duckdb/pg_duckdb.git
#
# WORKDIR /pg_duckdb
#
# RUN apt install -y  libssl-dev postgresql-server-dev-all
#
# RUN GEN=ninja && make install
#
# RUN ls
#
# FROM postgres:latest
#
# COPY --from=builder /usr/local/pgsql/lib/postgresql/pg_duckdb.so /usr/local/pgsql/lib/postgresql/pg_duckdb.so
#
# ENTRYPOINT ["psql", "-U", "postgres", "-d", "postgres"]
