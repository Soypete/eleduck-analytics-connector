FROM python:3.11-slim

WORKDIR /sqlmesh

# Install SQLMesh and dependencies
RUN pip install --no-cache-dir \
    sqlmesh[postgres] \
    pandas \
    && rm -rf /root/.cache

# Copy SQLMesh project
COPY sqlmesh/ /sqlmesh/

COPY docker/sqlmesh/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["plan", "--auto-apply"]
