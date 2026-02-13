"""SQLMesh project configuration."""

from sqlmesh.core.config import (
    Config,
    GatewayConfig,
    ModelDefaultsConfig,
    PostgresConnectionConfig,
)
import os

config = Config(
    project="eleduck_analytics",
    model_defaults=ModelDefaultsConfig(
        dialect="postgres",
        start="2020-01-01",
    ),
    gateways={
        "local": GatewayConfig(
            connection=PostgresConnectionConfig(
                host="localhost",
                port=5432,
                user=os.environ.get("POSTGRES_USER", "postgres"),
                password=os.environ.get("POSTGRES_PASSWORD", ""),
                database="analytics",
            ),
        ),
        "prod": GatewayConfig(
            connection=PostgresConnectionConfig(
                host=os.environ.get("POSTGRES_HOST", "postgres.eleduck-analytics.svc.cluster.local"),
                port=int(os.environ.get("POSTGRES_PORT", "5432")),
                user=os.environ.get("POSTGRES_USER", "postgres"),
                password=os.environ.get("POSTGRES_PASSWORD", ""),
                database=os.environ.get("POSTGRES_DB", "analytics"),
            ),
        ),
    },
    default_gateway="local",
    variables={
        "start_date": "2020-01-01",
        "fiscal_year_start_month": 7,
    },
)
