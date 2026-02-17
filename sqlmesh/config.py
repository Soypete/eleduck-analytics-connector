"""SQLMesh project configuration."""

from sqlmesh.core.config import (
    Config,
    GatewayConfig,
    ModelDefaultsConfig,
    DuckDBConnectionConfig,
)
import os

config = Config(
    project="eleduck_analytics",
    model_defaults=ModelDefaultsConfig(
        dialect="duckdb",
        start="2020-01-01",
    ),
    gateways={
        "local": GatewayConfig(
            connection=DuckDBConnectionConfig(
                database=":memory:",
            ),
        ),
        "prod": GatewayConfig(
            connection=DuckDBConnectionConfig(
                # MotherDuck connection string: md:database_name?motherduck_token=token
                database=os.environ.get(
                    "MOTHERDUCK_DATABASE",
                    f"md:{os.environ.get('MOTHERDUCK_DB_NAME', 'analytics')}?motherduck_token={os.environ.get('MOTHERDUCK_TOKEN', '')}"
                ),
            ),
        ),
    },
    default_gateway="local",
    variables={
        "start_date": "2020-01-01",
        "fiscal_year_start_month": 7,
    },
)
