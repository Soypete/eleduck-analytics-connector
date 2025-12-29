"""Seed models for SQLMesh - loading static reference data."""

import typing as t
from pathlib import Path

import pandas as pd
from sqlmesh import model
from sqlmesh.core.model.kind import ModelKindName


SEEDS_DIR = Path(__file__).parent.parent / "seeds"


@model(
    "analytics.seed_dim_date",
    kind=dict(name=ModelKindName.SEED, path=str(SEEDS_DIR / "dim_date.csv")),
    columns={
        "date_key": "INT",
        "full_date": "DATE",
        "year": "INT",
        "quarter": "INT",
        "month": "INT",
        "month_name": "TEXT",
        "week_of_year": "INT",
        "day_of_month": "INT",
        "day_of_week": "INT",
        "day_name": "TEXT",
        "is_weekend": "INT",
        "fiscal_year": "INT",
        "fiscal_quarter": "INT",
    },
    grain="date_key",
)
def seed_dim_date(evaluator) -> pd.DataFrame:
    """Date dimension seed from CSV."""
    return pd.read_csv(SEEDS_DIR / "dim_date.csv")


@model(
    "analytics.seed_platform_lookup",
    kind=dict(name=ModelKindName.SEED, path=str(SEEDS_DIR / "platform_lookup.csv")),
    columns={
        "platform_id": "TEXT",
        "platform_name": "TEXT",
        "platform_category": "TEXT",
        "platform_url": "TEXT",
    },
    grain="platform_id",
)
def seed_platform_lookup(evaluator) -> pd.DataFrame:
    """Platform lookup seed from CSV."""
    return pd.read_csv(SEEDS_DIR / "platform_lookup.csv")
