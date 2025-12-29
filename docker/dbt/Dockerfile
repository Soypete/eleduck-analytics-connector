FROM python:3.11-slim

WORKDIR /dbt

# Install dbt
RUN pip install --no-cache-dir \
    dbt-postgres==1.7.* \
    && rm -rf /root/.cache

# Copy DBT project
COPY dbt/ /dbt/

# Install packages
RUN dbt deps

COPY docker/dbt/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["build"]
