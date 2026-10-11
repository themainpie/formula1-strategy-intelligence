<div align="center">

# 🏎️ Formula 1 Strategy Intelligence

**An end-to-end Power BI project exploring race strategy, performance, and championship decisions**

[![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)](#technology-stack)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](#technology-stack)
[![DAX](https://img.shields.io/badge/DAX-80%20Measures-E10600?style=flat)](#dax-measure-library)
[![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat&logo=postgresql&logoColor=white)](#technology-stack)

*Built entirely with free tools: Power BI Desktop and Python. No Pro/Premium license, no paid AppSource visuals.*

[View Report](docs/F1_dashboard.pdf) · [Documentation](docs/) · [DAX Library](dax/DAX_Measures_Library.md)

</div>

---

## Overview

This portfolio project turns 70+ years of Formula 1 race results, qualifying, pit stop, and lap-level data into a decision-oriented Power BI report.

Each of the 8 dashboard pages is built around a decision that a **Team Principal**, **Race Engineer**, **Strategy Lead**, **Performance Engineer**, or **Sporting Director** might face before, during, or after a Grand Prix. Every KPI and DAX measure traces back to one of 50 documented business questions.

> The roles and business scenarios are hypothetical. I designed them to practice framing analysis around real stakeholder decisions.

**📁 Full documentation:** [`/docs`](docs/)

---

## Table of Contents

- [Business Problem](#business-problem)
- [Architecture](#architecture)
- [Data Model](#data-model)
- [Dashboard Pages](#dashboard-pages)
- [Dashboard Preview](#dashboard-preview)
- [KPI Framework](#kpi-framework)
- [DAX Measure Library](#dax-measure-library)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Future Roadmap](#future-roadmap)
- [Data Source & Disclaimer](#data-source--disclaimer)

---

## Business Problem

F1 teams generate large volumes of timing, strategy, and reliability data, but it often sits in disconnected systems that are hard to interrogate quickly under race-weekend time pressure. This project is built around three recurring problems:

1. **Strategy calls rely on incomplete historical context.** Undercut/overcut timing, pit windows, and tire degradation patterns aren't systematically compared across circuits and seasons.
2. **Driver and constructor performance is judged on outcome (points), not process (pace, consistency, grid conversion).** This makes it hard to separate a car problem from a driver problem or a strategy problem.
3. **Reliability and operational risk are reviewed reactively**, after a DNF costs a championship position, rather than tracked as a leading indicator.

### Intended Audience

| Role | Core Decision Supported |
|---|---|
| Team Principal | Season trajectory, resource allocation, driver/constructor investment |
| Sporting Director | Regulatory and championship-points strategy, reliability risk |
| Strategy Department | Pit windows, tire strategy, undercut/overcut timing per circuit |
| Race Engineers | Driver-specific pace and consistency trends, setup feedback |
| Performance Engineers | Car performance vs. grid, sector-level competitiveness |

### Intended Value

- Support evidence-based strategy discussions instead of gut-feel pit calls
- Benchmark drivers objectively, including teammate comparisons
- Surface reliability risk early, as a leading indicator rather than a post-mortem
- Provide a model structure that can be extended as new seasons of data arrive

---

## Architecture

```
Raw CSVs (Kaggle: Formula 1 Race Data)
        │
        ▼
   Python ETL & Feature Engineering
   (etl.ipynb → feature_engineering.ipynb → advanced_analytics.ipynb)
        │
        ├──────────────► SQL layer (optional, warehouse-style queries)
        │
        ▼
   Power Query (M): star schema shaping, surrogate keys, type enforcement
        │
        ▼
   Star Schema Semantic Model: 6 fact tables, 8 dimension tables (Power BI)
        │
        ▼
   DAX Measure Layer: 80 measures
        │
        ▼
   8-Page Power BI Report: native visuals only, no Pro/Premium required
   (Executive · Driver · Constructor · Qualifying · Pit Stop & Strategy ·
    Race Pace & Tires · Reliability & Risk · Circuit Intelligence)
```

### Pipeline

1. **Extract**: raw Kaggle CSVs (`results`, `races`, `drivers`, `constructors`, `qualifying`, `pit_stops`, `lap_times`, `status`, `circuits`).
2. **Transform (Python)**: cleaning, name normalization, and feature engineering (grid deltas, stint boundaries, teammate comparisons, driver/constructor livery color mapping, tire degradation slopes).
3. **Transform (Power Query)**: final shaping into the star schema, surrogate keys, a generated calendar dimension, and a structure that would suit incremental refresh.
4. **Load**: Power BI semantic model with a documented DAX library of 80 measures.
5. **Serve**: 8-page report with a custom dark theme and per-team, per-driver livery colors.

See [`/notebooks`](notebooks/) for the notebooks and [`/sql`](sql/) for the SQL layer, written as if it fed a warehouse instead of flat files.

---

## Data Model

Star schema with **6 fact tables** and **8 dimension tables**. Full grain, relationships, and modeling rationale: [`docs/Data_Dictionary.md`](docs/Data_Dictionary.md).

| Fact Tables | Dimension Tables |
|---|---|
| `FactRaceResults` | `DimDriver`, `DimConstructor`, `DimCircuit` |
| `FactLapTimes`, `FactPitStops`, `FactQualifying` | `DimRace`, `DimSeason`, `DimDate`, `DimStatus`, `DimDriverSeasonColor` |
| `FactStints`, `FactDriverSeasonStats` | |

`FactQualifying` is modeled separately from `FactRaceResults` on purpose: raw one-lap qualifying pace and the post-penalty starting grid position answer different business questions, and collapsing them into one column would hide that distinction. `DimSeason` is a dedicated season-grain dimension so season-level features (teammate deltas, driver color assignment) relate cleanly without forcing season logic through the race-grain table. No fact table relates directly to another. Cross-fact questions (e.g., "did the pole-sitter go on to win?") are answered with `TREATAS`-based DAX bridging through shared dimensions, which keeps every relationship in the model at a single, unambiguous grain.

---

## Dashboard Pages

| # | Page | Primary Audience | Answers |
|---|---|---|---|
| 1 | Executive Overview | Team Principal, Sporting Director | Season trajectory, standings, momentum |
| 2 | Driver Performance | Race Engineers, Team Principal | Consistency, grid conversion, teammate comparison |
| 3 | Constructor Performance | Team Principal, Performance Engineers | Reliability, development trajectory, competitive spread |
| 4 | Qualifying Intelligence | Strategy Department, Race Engineers | Grid-to-finish predictability, Q1/Q2/Q3 conversion |
| 5 | Pit Stop & Strategy | Strategy Department, Race Engineers | Pit windows, undercut value, execution quality |
| 6 | Race Pace & Tire Strategy | Performance Engineers, Strategy Department | Stint pace, degradation, field spread |
| 7 | Reliability & Risk | Sporting Director, Team Principal | DNF rate, mechanical risk, points cost of failure |
| 8 | Circuit Intelligence | Strategy, Race & Performance Engineers | What each circuit rewards, overtaking, historical winners |

---

## Dashboard Preview

<div align="center">
<img src="images/dashboard_overview.png" alt="Dashboard overview: all 8 pages" width="800"/>
</div>

<details>
<summary><strong>Individual page layouts</strong></summary>

| Executive Overview | Driver Performance |
|---|---|
| ![Executive Overview](images/executive_overview.png) | ![Driver Performance](images/driver_performance.png) |

| Constructor Performance | Qualifying Intelligence |
|---|---|
| ![Constructor Performance](images/constructor_performance.png) | ![Qualifying Intelligence](images/qualifying_intelligence.png) |

| Pit Stop & Strategy | Race Pace & Tire Strategy |
|---|---|
| ![Pit Stop & Strategy](images/pit_stop_and_strategy.png) | ![Race Pace & Tire Strategy](images/race_pace_and_tire_strategy.png) |

| Reliability & Risk | Circuit Intelligence |
|---|---|
| ![Reliability & Risk](images/reliability_and_risk.png) | ![Circuit Intelligence](images/circuit_intelligence.png) |

</details>

---

## KPI Framework

**30 KPIs** spanning results, consistency, strategy execution, and reliability, grouped by the audience each one serves. Full definitions and formulas: [`docs/KPI_Definitions.md`](docs/KPI_Definitions.md).

| KPI | What It Isolates |
|---|---|
| Driver Consistency Score | How reliably a driver finishes where pace suggests, independent of car performance |
| Teammate Delta (Qualifying) | Pure one-lap pace, isolated from grid penalties and race-day variance |
| Constructor Reliability | Car-caused DNFs only, separating a car problem from a driver problem |
| Pit Window Variance | How exploitable a circuit's pit strategy timing is |
| Season Parity Index | League-wide competitive balance trend, not just one team's form |

---

## DAX Measure Library

**80 measures across 13 display folders**: [`dax/DAX_Measures_Library.md`](dax/DAX_Measures_Library.md). A few patterns worth a technical reviewer's attention:

- **Cross-fact bridging via `TREATAS`.** No two fact tables share a direct relationship. Measures like `Pole to Win Rate` and `Multi-Stop Race Win Rate` build a virtual key table from one fact table and push it onto another, keeping every relationship at a single, correct grain.
- **Season-guarded comparison measures.** Teammate and career-comparison KPIs require a single-season selection before returning a value, so they can't be silently misread when aggregated across multiple seasons.
- **Native-only visual techniques.** A floating-bar chart (transparent base plus a visible range segment, built as a Stacked Column + Line combo) gives box-plot-style distribution views using only Power BI's built-in visuals. The full implementation is included.
- **Explicit modeling assumptions.** Measures with inherent simplifications (e.g., `Max Possible Points`, `Expected Points If Finished`) are documented with their assumptions stated plainly rather than presented as more precise than they are.

---

## Technology Stack

- **Power BI Desktop**: semantic model, DAX, and report layer, using native visuals only (no Pro/Premium, no paid AppSource visuals)
- **Python** (`pandas`, `numpy`, `scikit-learn`, `matplotlib`, `pyarrow`): ETL, feature engineering, clustering, and tire degradation modeling
- **SQL**: analytical query layer (window functions, CTEs, ranking), written as if served from a warehouse
- **Power Query (M)**: transformation and star-schema shaping
- **GitHub**: version control and portfolio presentation

---

## Project Structure

```
Formula-1-Strategy-Intelligence/
│
├── docs/
│   ├── Business_Requirements.md
│   ├── Data_Dictionary.md
│   ├── KPI_Definitions.md
│   ├── Power_Query_Transformations.md
│   └── F1_dashboard.pdf
│
├── sql/
│   ├── schema.sql
│   ├── analytical_queries.sql
│   └── load_data.py
│
├── notebooks/
│   ├── etl.ipynb
│   ├── feature_engineering.ipynb
│   ├── advanced_analytics.ipynb
│   └── Analytics_Plan.md
│
├── dax/
│   └── DAX_Measures_Library.md
│
├── Formula1_Strategy_Intelligence.pbix
├── F1_Strategy_Intelligence_Theme.json
│
├── images/
│   ├── executive_overview.png
│   ├── driver_performance.png
│   ├── constructor_performance.png
│   ├── qualifying_intelligence.png
│   ├── pit_stop_and_strategy.png
│   ├── race_pace_and_tire_strategy.png
│   ├── reliability_and_risk.png
│   ├── circuit_intelligence.png
│   └── dashboard_overview.png
│
├── README.md
└── requirements.txt
```

**Folder rationale:** `docs/` is what a reviewer reads before opening the `.pbix`: the business case, data contract, and design rationale. `dax/` has its own folder because it's typically the first thing a technical reviewer checks. `notebooks/` shows my Python work independent of Power BI. `Formula1_Strategy_Intelligence.pbix` is the main deliverable.

---

## Future Roadmap

- Simulate a live/near-live timing feed in place of the static CSV load
- Python-based race strategy simulator (undercut/overcut expected-value model) surfaced via a Power BI Python visual
- Predictive reliability scoring using scikit-learn
- Safety-car period detection via lap-time anomaly clustering, feeding a dedicated strategy-risk KPI
- Row-level security to simulate multi-team access patterns

---

## Data Source & Disclaimer

Uses the public [Formula 1 Race Data dataset](https://www.kaggle.com/datasets/jtrotman/formula-1-race-data) on Kaggle. This is an independent portfolio project, not affiliated with or endorsed by Formula 1, the FIA, or any team. All team and driver names and colors are used for illustrative purposes only.
