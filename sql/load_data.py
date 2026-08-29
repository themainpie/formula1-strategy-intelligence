"""
load_data.py — loads cleaned parquet files, maps columns to schema.sql
names, loads into SQLite for Power BI.
"""

import sqlite3
from pathlib import Path

import pandas as pd

PROCESSED_DIR = Path("../data/processed")
DB_PATH = Path("f1_strategy.db")


def rp(name):
    return pd.read_parquet(PROCESSED_DIR / f"{name}.parquet")


def build_dim_driver():
    df = rp("drivers")
    return pd.DataFrame({
        "driver_id": df["driverId"],
        "full_name": df["FullName"],
        "driver_code": df["DriverCode"],
        "nationality": df["nationality"],
        "date_of_birth": df["dob"],
    })


def build_dim_constructor():
    df = rp("constructors")
    return pd.DataFrame({
        "constructor_id": df["constructorId"],
        "constructor_name": df["name"],
        "nationality": df["nationality"],
    })


def build_dim_circuit():
    df = rp("circuits")
    return pd.DataFrame({
        "circuit_id": df["circuitId"],
        "circuit_name": df["name"],
        "country": df["country"],
        "location": df["location"],
        "circuit_type": df["CircuitType"],
    })


def build_dim_race():
    df = rp("races")
    return pd.DataFrame({
        "race_id": df["raceId"],
        "circuit_id": df["circuitId"],
        "season": df["Season"],
        "round": df["Round"],
        "race_name": df["RaceName"],
        "race_date": df["race_date"],
    })


def build_dim_status():
    df = rp("status")
    return pd.DataFrame({
        "status_id": df["statusId"],
        "status_description": df["status"],
        "status_category": df["StatusCategory"],
    })


def build_fact_race_results():
    df = rp("results")
    return pd.DataFrame({
        "result_sk": df["resultId"],
        "race_id": df["raceId"],
        "driver_id": df["driverId"],
        "constructor_id": df["constructorId"],
        "status_id": df["statusId"],
        "grid_position": df["grid"],
        "finish_position": df["FinishPosition"],
        "points": df["points"],
        "laps_completed": df["laps"],
    })


def build_fact_pit_stops():
    df = rp("pit_stops")
    return pd.DataFrame({
        "race_id": df["raceId"],
        "driver_id": df["driverId"],
        "stop_number": df["stop"],
        "lap": df["lap"],
        "duration_ms": df["DurationMs"],
    })


def build_fact_lap_times():
    df = rp("lap_times")
    return pd.DataFrame({
        "race_id": df["raceId"],
        "driver_id": df["driverId"],
        "lap_number": df["lap"],
        "position": df["position"],
        "lap_time_ms": df["LapTimeMs"],
    })


TABLES = {
    "dim_driver": build_dim_driver,
    "dim_constructor": build_dim_constructor,
    "dim_circuit": build_dim_circuit,
    "dim_race": build_dim_race,
    "dim_status": build_dim_status,
    "fact_race_results": build_fact_race_results,
    "fact_pit_stops": build_fact_pit_stops,
    "fact_lap_times": build_fact_lap_times,
}


def main():
    with sqlite3.connect(DB_PATH) as conn:
        for name, builder in TABLES.items():
            df = builder()
            df.to_sql(name, conn, if_exists="replace", index=False)
            print(f"{name:20s} {len(df):>8,} rows")
    print(f"\nLoaded into {DB_PATH}")


if __name__ == "__main__":
    main()