FROM python:3.11-slim

WORKDIR /sqlmesh

# Install system dependencies for psycopg2
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install SQLMesh and dependencies
RUN pip install --no-cache-dir \
    'sqlmesh[postgres,duckdb]' \
    pandas \
    && rm -rf /root/.cache

# Copy SQLMesh project
COPY sqlmesh/ /sqlmesh/

COPY docker/sqlmesh/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["plan", "--auto-apply"]
