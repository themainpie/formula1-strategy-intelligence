# Data Dictionary & Star Schema
## Formula 1 Strategy Intelligence Platform

Source: [Kaggle — Formula 1 Race Data](https://www.kaggle.com/datasets/jtrotman/formula-1-race-data) (`results`, `races`, `drivers`, `constructors`, `qualifying`, `pit_stops`, `lap_times`, `status`, `circuits`, `driver_standings`, `constructor_standings`).

---

## 1. Schema Type & Rationale

**Star schema**, not snowflake. Every dimension in F1 data (driver, constructor, circuit, race) is low-cardinality and doesn't benefit from further normalization — snowflaking here would only add join complexity and hurt DAX performance for no analytical gain. One-to-many relationships flow from dimensions into facts, filter direction is single (dimension → fact) everywhere except the driver/constructor standings bridge, which needs bidirectional filtering to support both "standings as of this race" and "season totals" simultaneously.

## 2. Source Table → Star Schema Mapping

**Important naming clarification:** every `Fact`/`Dim` table below is a **renamed and cleaned version of a single source CSV** — none of them are merges of multiple source files into one table. The `Fact`/`Dim` prefixes are the star-schema naming convention applied only at the final Power Query load step; your Python notebooks and the raw data keep the original Kaggle file names throughout. `FactRaceResults` relates to `DimRace` via the `RaceID` foreign key exactly like any other fact-to-dimension relationship — it does not contain race-level columns physically merged in.

| Star Schema Table | Source File | Grain (unchanged from source) |
|---|---|---|
| `FactRaceResults` | `results.csv` | one row per driver, per race |
| `FactLapTimes` | `lap_times.csv` | one row per driver, per lap, per race |
| `FactPitStops` | `pit_stops.csv` | one row per pit stop |
| `FactQualifying` | `qualifying.csv` | one row per driver, per race |
| `FactStints` | `stints.parquet`, generated in `feature_engineering.ipynb` (enriched with `DegradationSlope` in `advanced_analytics.ipynb`) | one row per driver, per stint, per race |
| `FactDriverSeasonStats` | `teammate_deltas.parquet`, generated in `feature_engineering.ipynb` | one row per driver, per season, per constructor stint |
| `DimRace` | `races.csv` (enriched with a `CircuitType` lookup merge — see below) | one row per race |
| `DimDriver` | `drivers.csv` | one row per driver |
| `DimConstructor` | `constructors.csv` | one row per constructor |
| `DimCircuit` | `circuits.csv` | one row per circuit |
| `DimStatus` | `status.csv` | one row per status code |
| `DimDate` | *generated in Power Query* via `CALENDAR()`, not sourced from a CSV | one row per calendar day |
| `DimSeason` | *generated in Power Query* via `Table.Distinct()` on `DimRace[Season]`, not sourced from a CSV | one row per season |
| `DimDriverSeasonColor` | `driver_season_colors.parquet`, generated in `feature_engineering.ipynb` (not a raw Kaggle file) | one row per driver, per season |

*`rolling_form.parquet` is also generated in `feature_engineering.ipynb` but is intentionally not a model table — see the note above the Dimension Tables section for why (its grain matches `FactRaceResults` exactly, so it merges in as columns rather than adding another table).*

**The one exception worth flagging:** `DimRace` does pull in `CircuitType` and a couple of display columns (`CircuitName`, `Country`) from `circuits.csv` during Power Query shaping, purely for convenience so common report-level filtering doesn't require an extra hop through `DimCircuit`. The full circuit dimension (`DimCircuit`) still exists separately for anything that needs the complete circuit attribute set (lat/lng, etc.). This is a denormalization convenience, not a grain change — `DimRace` still has exactly one row per race either way.

## 2b. Fact Tables

### FactRaceResults (grain: one row per driver, per race)
| Column | Type | Notes |
|---|---|---|
| ResultSK | int | surrogate key |
| RaceID (FK) | int | → DimRace |
| DriverID (FK) | int | → DimDriver |
| ConstructorID (FK) | int | → DimConstructor |
| StatusID (FK) | int | → DimStatus |
| GridPosition | int | starting position |
| FinishPosition | int | null if DNF |
| Points | decimal | |
| Laps | int | laps completed |
| FastestLapRank | int | nullable |
| FastestLapTimeMs | int | nullable |
| PositionsGained | int (calc) | Grid − Finish |
| IsDNF | boolean (calc) | derived from StatusID |
| IsPodium | boolean (calc) | FinishPosition ≤ 3 |
| IsWin | boolean (calc) | FinishPosition = 1 |

### FactLapTimes (grain: one row per driver, per lap, per race)
| Column | Type | Notes |
|---|---|---|
| RaceID (FK) | int | |
| DriverID (FK) | int | |
| LapNumber | int | |
| Position | int | track position at end of lap |
| LapTimeMs | int | |

*Note: this is the highest-volume table — kept separate from FactRaceResults to avoid bloating the primary fact table's row size, and only pulled into visuals that specifically need lap-level granularity (pace trend, tire degradation).*

### FactPitStops (grain: one row per pit stop)
| Column | Type | Notes |
|---|---|---|
| RaceID (FK) | int | |
| DriverID (FK) | int | |
| StopNumber | int | 1st, 2nd, 3rd stop of the race |
| Lap | int | lap the stop occurred on |
| DurationMs | int | stationary time |

### FactQualifying (grain: one row per driver, per race)
| Column | Type | Notes |
|---|---|---|
| RaceID (FK) | int | → DimRace |
| DriverID (FK) | int | → DimDriver |
| QualifyingPosition | int | raw session result, **before** any grid penalties |
| Q1TimeMs | int | nullable — null if not set (rare, e.g. no representative time) |
| Q2TimeMs | int | nullable — null if eliminated in Q1 |
| Q3TimeMs | int | nullable — null if eliminated in Q2 |
| EliminatedInQ1 | boolean (calc) | Q2TimeMs is null |
| EliminatedInQ2 | boolean (calc) | Q2TimeMs not null and Q3TimeMs is null |

**Important distinction from `FactRaceResults[GridPosition]`:** `QualifyingPosition` here is the raw one-lap-pace result from Saturday. `FactRaceResults[GridPosition]` is the *actual* starting position after grid penalties (engine changes, impeding, disqualifications) are applied. Both matter and answer different business questions — don't collapse them into one column. A large gap between the two for a given driver-race is itself a useful derived signal (penalty impact), worth a `GridPenaltyPositions = GridPosition - QualifyingPosition` calculated column on `FactRaceResults` once both tables are loaded.

### FactStints (grain: one row per driver, per stint, per race)
| Column | Type | Notes |
|---|---|---|
| RaceID (FK) | int | → DimRace |
| DriverID (FK) | int | → DimDriver |
| StintNumber | int | 1st, 2nd, 3rd stint of that driver's race |
| StartLap | int | |
| EndLap | int | |
| LapCount | int (calc) | EndLap − StartLap + 1 |
| AvgStintLapTimeMs | float | mean lap time across the stint |
| DegradationSlope | float | ms/lap, from the linear fit in `advanced_analytics.ipynb` |

**Previously undocumented — corrected here.** This table has existed as `stints.parquet` (from `feature_engineering.ipynb`, enriched with `DegradationSlope` in `advanced_analytics.ipynb`) since early in this project, but was never actually added to this doc. Relationships are the standard fan-out pattern, same as `FactPitStops`/`FactLapTimes` — `DimRace[RaceID]` (1) → `FactStints[RaceID]` (many), `DimDriver[DriverID]` (1) → `FactStints[DriverID]` (many). No fact-to-fact relationship, same reasoning as elsewhere in this doc. Feeds Dashboard Page 6.

### FactDriverSeasonStats (grain: one row per driver, per season, per constructor stint)
| Column | Type | Notes |
|---|---|---|
| Season (FK) | int | → DimSeason (**not** DimRace — see the DimSeason note below) |
| ConstructorID (FK) | int | → DimConstructor |
| DriverID (FK) | int | → DimDriver |
| SeasonPoints | float | |
| AvgGridPosition | float | post-penalty starting position, averaged across the season |
| AvgQualifyingPosition | float | raw one-lap pace, averaged across the season |
| RacesForConstructor | int | |
| TeammatePoints / TeammatePointsDelta | float | see `docs/KPI_Definitions.md` #14 |
| TeammateGridDelta / TeammateQualifyingDelta | float | see `docs/KPI_Definitions.md` #15 |
| RookieSeasonIndex | float | nullable — only populated in a driver's debut season |

**Previously undocumented — corrected here.** This has existed as `teammate_deltas.parquet` since `feature_engineering.ipynb` Section 2, but was likewise never added to this doc — worth naming here because its grain (per **season**, not per race) is exactly what makes its relationships different from every other fact table in this model. Relates via `DimSeason[Season]` (1) → many, `DimConstructor[ConstructorID]` (1) → many, `DimDriver[DriverID]` (1) → many. A driver who changed constructors mid-season gets more than one row this season (one per constructor stint) — that's expected, not a duplicate-row bug, and is exactly why the grain includes `ConstructorID` rather than being Season+DriverID alone.

**A fourth feature file, `rolling_form.parquet` (also from `feature_engineering.ipynb`), is deliberately NOT a fifth fact table.** Its grain (`RaceID` + `DriverID`) is identical to `FactRaceResults` — merge its two columns (`Rolling5RaceAvgPoints`, `Rolling5RaceAvgPositionsGained`) directly onto `FactRaceResults` in Power Query via a merge on `RaceID`+`DriverID`, rather than adding another set of fan-out relationships for a table that adds no new grain. Its actual purpose is as a Python-side cross-check against DAX measure #39 (`Rolling 5-Race Points Avg`), not as a permanent model table — see `python/feature_engineering.ipynb` Section 4.

## 3. Dimension Tables

### DimSeason
Season (PK)

A small generated table — `Table.Distinct(Table.SelectColumns(DimRace, {"Season"}))` in Power Query — not sourced from any CSV. **This exists specifically to fix a cardinality bug**: `DimRace[Season]` has ~20-24 repeated rows per season (one per race), so it cannot serve as the "one" side of a relationship — anything that needs to relate to the model at season grain (`FactDriverSeasonStats`, `DimDriverSeasonColor`) has to go through `DimSeason` instead, not `DimRace[Season]` directly. `DimSeason[Season]` (1) → `DimRace[Season]` (many) is the correct direction; the reverse was the bug (see the `DimDriverSeasonColor` correction below).

### DimDate
Date (PK), Year, Quarter, Month, MonthName, Day, DayOfWeek, IsWeekend

A standard contiguous calendar table (`CALENDAR(MIN(DimRace[Date]), MAX(DimRace[Date]))` or `CALENDARAUTO()`), one row per calendar day, marked as the model's **Date Table** in Power BI. Related to `DimRace[Date]` (one-to-many, `DimDate` is the "one" side).

**Correction from an earlier version of this document:** this doc previously described `DimRace` as "also serving as the DimDate anchor." That's wrong for anything using built-in DAX time intelligence functions (`TOTALYTD`, `SAMEPERIODLASTYEAR`, `DATESINPERIOD`, etc.) — those require a genuine contiguous one-row-per-day table, and `DimRace` only has one row per race weekend (~20-24 rows/season). Using `DimRace[Date]` directly with those functions doesn't error, it just silently returns wrong results — which is exactly what happened in an earlier draft of `dax/DAX_Measures_Library.md` (measures #36/#37/#40). `DimRace` is fine as the direct relationship target for ordinary (non-time-intelligence) filtering and slicing by race; `DimDate` is only needed for the specific handful of measures that use true time intelligence functions.

### DimRace
RaceID (PK), CircuitID (FK), Season, Round, RaceName, Date, Year, IsSprintWeekend

### DimDriver
DriverID (PK), FullName, Nationality, DateOfBirth, DriverCode, AgeAtRace (calc in fact or via relationship to DimRace date)

### DimConstructor
ConstructorID (PK), ConstructorName, Nationality, PrimaryColorHex, SecondaryColorHex, IsOfficialColor

`PrimaryColorHex`/`SecondaryColorHex` come from `feature_engineering.ipynb` Section 5 (`driver_season_colors.parquet` also carries the constructor-level colors, merged onto `constructors_df` before export). `IsOfficialColor` flags whether the color came from the verified 2025-season mapping or a generated fallback for historical/unmatched constructors — worth surfacing in a chart tooltip if you want to be transparent that pre-2025 or defunct teams aren't using their real historical livery colors, since no consistently authoritative source exists for those.

### DimDriverSeasonColor
Season, DriverID (FK), ConstructorID (FK), ColorHex, IsPrimaryDriver

A small supplementary table (from `driver_season_colors.parquet`) rather than a column directly on `DimDriver`, because a driver's color **depends on which season and which teammate** — the same driver can be the primary-color driver one season and the secondary-color driver the next (e.g., after a new signing outscores them), so this can't live as a static attribute on `DimDriver` itself. Relate to `DimSeason[Season]` (1 → many) and `DimDriver[DriverID]` (1 → many). Use `ColorHex` directly for "Format by field value" on any driver-level chart — see `docs/Dashboard_Design.md` for exactly which visuals this applies to and how to wire it in.

**Correction from an earlier version of this document:** this section previously said to relate to `DimRace[Season]`. That's the same cardinality bug fixed above for `FactDriverSeasonStats` — `DimRace[Season]` isn't unique, so it can't be the "one" side of a relationship into a season-grain table. Route through `DimSeason` instead. If you already built this relationship in Power BI against `DimRace[Season]` directly, Power BI would have either rejected it outright or (if it let you create it as many-to-many) silently produced wrong filter propagation — worth checking your actual model against this if you built it before this correction.

### DimCircuit
CircuitID (PK), CircuitName, Country, Location, Lat, Lng, CircuitType (Street/Permanent/Hybrid — engineered flag)

### DimStatus
StatusID (PK), StatusDescription, StatusCategory (calc: Finished / Mechanical DNF / Driver DNF / Accident)

### BridgeDriverConstructorSeason
Handles drivers who changed teams mid-season (rare but present in the data) — DriverID, ConstructorID, Season, RaceIDRangeStart, RaceIDRangeEnd. Prevents a driver's full-season points from double-counting against two constructors.

## 4. Relationship Diagram (textual)

**Fact tables never relate directly to each other.** Each fact table connects independently to the shared dimensions (`DimRace`, `DimDriver`), and cross-fact filtering happens automatically through those dimensions — this is standard star-schema fan-out, not an ambiguous pattern, and it's what makes selecting a driver or a season filter all three fact tables at once without a direct fact-to-fact link.

```
DimDriver ──┬────────────► FactRaceResults
            ├────────────► FactLapTimes
            ├────────────► FactPitStops
            ├────────────► FactQualifying
            ├────────────► FactStints
            ├────────────► FactDriverSeasonStats
            └────────────► DimDriverSeasonColor

DimRace ────┬────────────► FactRaceResults
            ├────────────► FactLapTimes
            ├────────────► FactPitStops
            ├────────────► FactQualifying
            └────────────► FactStints

DimConstructor ─────────┬─► FactRaceResults
                         └─► FactDriverSeasonStats

DimStatus ──────────────► FactRaceResults
DimRace ────────────────► DimCircuit
DimRace ────────────────► DimSeason   (many-to-one: many races per season)

DimSeason ──────────────┬─► FactDriverSeasonStats
                         └─► DimDriverSeasonColor
```

**`DimSeason` is the fix for a real bug an earlier version of this document had:** `FactDriverSeasonStats` and `DimDriverSeasonColor` are both season-grain tables (one row per driver per season), but `DimRace` only has `Season` as a repeated column — ~20-24 rows share the same season value, so `DimRace[Season]` can't be the "one" side of a relationship into either of them. `DimSeason[Season]` is a small generated table with `Season` as a genuinely unique key, which both season-grain tables relate to instead. Note the relationship direction: it's `DimRace[Season]` (many) → `DimSeason[Season]` (one), the reverse of every other arrow in this diagram — `DimSeason` is upstream of `DimRace`, not downstream of it.

That's now fourteen fact/dimension relationships across six fact-grain tables (`FactRaceResults`, `FactLapTimes`, `FactPitStops`, `FactQualifying`, `FactStints`, `FactDriverSeasonStats`) plus the season-grain `DimDriverSeasonColor`. All fact-to-dimension relationships are single-direction (dimension filters fact), except `DimDriver`/`DimConstructor` → `BridgeDriverConstructorSeason`, which is bidirectional to correctly attribute mid-season team changes to standings measures.

**Why not relate `FactLapTimes`/`FactPitStops`/`FactQualifying`/`FactStints` directly to `FactRaceResults`?** `FactRaceResults` has one row per driver per race, so neither `RaceID` nor `DriverID` alone is unique on that table — it can't serve as the "one" side of a relationship to the finer-grain fact tables. If you need to filter lap times or pit stops by something that only lives on `FactRaceResults` (e.g., "laps for podium finishers only"), don't build a relationship for it — either denormalize the flag onto the finer-grain fact table during Power Query shaping, or use a `TREATAS`-based DAX measure to push the filter across at query time.

*(Note: `FactQualifying` shares the same grain as `FactRaceResults` — one row per driver per race — so in principle a one-to-one relationship between the two is technically valid in Power BI. It's still recommended to connect both independently to `DimRace`/`DimDriver` rather than chaining `FactQualifying` through `FactRaceResults`, to keep the fan-out pattern consistent and avoid accidentally creating an ambiguous alternate filter path once both relationships exist.)*

## 5. Surrogate Keys

Natural keys from the Kaggle CSVs (`driverId`, `constructorId`, `raceId`, `circuitId`, `statusId`) are reused as surrogate keys directly — they're already stable, unique integers, so generating new ones would add complexity with no benefit. Where composite grain is needed (pit stops, lap times), a composite key of `RaceID + DriverID + LapNumber` / `+ StopNumber` is used rather than a synthetic identity column, since Power BI relationships handle composite-key scenarios better via a concatenated key column than via multi-column relationships.

## 6. Why This Model Follows BI Best Practice

- **Single fact table for the core grain (race result)** keeps the primary measures (points, wins, positions) fast and simple — most DAX measures only need to touch `FactRaceResults`.
- **Lap times and pit stops split into their own fact tables** rather than merged into the results fact, because their grain is far finer (per lap / per stop vs. per race) — merging them would force `FactRaceResults` to explode to lap-level grain, wrecking every season-level aggregation's performance.
- **Qualifying kept as its own fact table rather than merged into `FactRaceResults`**, even though both share the same grain (one row per driver per race). They represent genuinely different events — Saturday qualifying pace vs. Sunday's actual race outcome — and a driver's `GridPosition` (post-penalty) can legitimately differ from their `QualifyingPosition` (raw session result). Keeping them separate preserves that distinction instead of forcing a single "position" column to represent two different things.
- **Status normalized into its own dimension** rather than left as a free-text column, because "reliability" is a first-class business question (Q36–40) and needs a clean `StatusCategory` to group 130+ raw status strings into Finished / Mechanical / Driver Error / Accident.
- **Bridge table for mid-season constructor changes** avoids the classic F1-data pitfall where a driver's points get misattributed to the wrong constructor for part of a season.
