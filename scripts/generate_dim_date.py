#!/usr/bin/env python3
"""Generate dim_date seed CSV for DBT."""

import csv
from datetime import date, timedelta


def get_fiscal_year(d: date, fiscal_start_month: int = 7) -> int:
    """Fiscal year starts in July."""
    if d.month >= fiscal_start_month:
        return d.year + 1
    return d.year


def get_fiscal_quarter(d: date, fiscal_start_month: int = 7) -> int:
    """Calculate fiscal quarter (1-4)."""
    adjusted_month = (d.month - fiscal_start_month) % 12
    return (adjusted_month // 3) + 1


def generate_dim_date(start_date: date, end_date: date) -> list[dict]:
    """Generate date dimension records."""
    records = []
    current = start_date

    while current <= end_date:
        records.append({
            'date_key': int(current.strftime('%Y%m%d')),
            'full_date': current.isoformat(),
            'year': current.year,
            'quarter': (current.month - 1) // 3 + 1,
            'month': current.month,
            'month_name': current.strftime('%B'),
            'week_of_year': current.isocalendar()[1],
            'day_of_month': current.day,
            'day_of_week': current.isoweekday(),
            'day_name': current.strftime('%A'),
            'is_weekend': 1 if current.weekday() >= 5 else 0,
            'fiscal_year': get_fiscal_year(current),
            'fiscal_quarter': get_fiscal_quarter(current)
        })
        current += timedelta(days=1)

    return records


if __name__ == '__main__':
    start = date(2020, 1, 1)
    end = date(2030, 12, 31)

    records = generate_dim_date(start, end)

    with open('dbt/seeds/dim_date.csv', 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)

    print(f"Generated {len(records)} date records")
