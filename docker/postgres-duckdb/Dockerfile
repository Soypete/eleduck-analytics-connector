FROM postgres:16-bookworm

LABEL org.opencontainers.image.source="https://github.com/Soypete/eleduck-analytics-connector"
LABEL org.opencontainers.image.description="PostgreSQL 16 with pg_duckdb extension"

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libreadline-dev \
    zlib1g-dev \
    postgresql-server-dev-16 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone and build pg_duckdb
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/duckdb/pg_duckdb.git \
    && cd pg_duckdb \
    && make install \
    && cd / \
    && rm -rf /tmp/pg_duckdb

# Add pg_duckdb to shared_preload_libraries
RUN echo "shared_preload_libraries = 'pg_duckdb'" >> /usr/share/postgresql/postgresql.conf.sample

# Clean up build dependencies to reduce image size
RUN apt-get remove -y \
    build-essential \
    cmake \
    git \
    postgresql-server-dev-16 \
    && apt-get autoremove -y \
    && apt-get clean

WORKDIR /
