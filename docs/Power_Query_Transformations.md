# Power Query (M) Transformation Plan
## Formula 1 Strategy Intelligence Platform

Applied per source table, in the order listed — order matters for refresh performance and for avoiding step-order bugs (e.g., type conversion before null-handling can silently coerce errors).

## Global Steps (applied to every table)
1. **Promote headers / set correct data types immediately** — avoids Power Query's "Changed Type" auto-step guessing wrong on numeric-looking text (e.g., driver codes like "044" that should stay text).
2. **Remove columns not used anywhere in the model** (source URLs, unused free-text fields) — smaller model, faster refresh.
3. **Trim/Clean text columns** to remove hidden whitespace from CSV exports before any grouping or joins.

## `drivers`
- Normalize name casing (Proper Case) — source data is inconsistent (all caps for some historical entries)
- Concatenate `forename` + `surname` into `FullName`, retain both source columns for search/filter flexibility
- Handle missing `dob` for a small number of very old records → flag `IsDOBEstimated` rather than dropping the row
- Create `DriverCode` fallback for pre-2014 drivers who don't have an official 3-letter code (derive first 3 letters of surname, flagged as `IsCodeDerived`)

## `constructors`
- Normalize constructor name changes across eras (e.g., team renames/rebrands) into a `ConstructorGroupID` so a team that changed names mid-history can still be trended continuously if desired, while `ConstructorName` keeps the historically accurate label per season

## `races` / `circuits`
- Merge `races` with `circuits` on `circuitId` to enrich each race with location metadata
- Derive `CircuitType` (Street / Permanent / Hybrid) via a manually maintained mapping table merged in, since the source data doesn't include this classification
- Parse `date` and `time` columns into proper `datetime`, derive `Season`, `Round`, `RaceWeekend` groupings

## `results`
- Remove duplicate rows (rare but present from merge artifacts) using `Table.Distinct` on the natural key (`raceId`, `driverId`)
- Replace non-numeric placeholder values (`\N`) in `position`, `fastestLapTime`, etc. with proper nulls before type conversion — this is the single most important step, since leaving `\N` as text silently breaks every downstream numeric measure
- Split `time` (gap to leader, stored as a string like `+5.291s`) into a numeric `GapSeconds` column
- Create calculated columns: `PositionsGained` (grid − position), `IsDNF`, `IsPodium`, `IsWin`

## `qualifying`
- Convert `q1`/`q2`/`q3` lap time strings (`mm:ss.SSS`) into millisecond integers via a custom M function (`fnParseLapTime`) reused across this table and `lap_times`
- Derive `EliminatedInQ1` / `EliminatedInQ2` flags based on which columns are null

## `pit_stops`
- Convert `duration` string to milliseconds (numeric)
- Create composite key `RaceID-DriverID-StopNumber` for the relationship to `FactPitStops`
- Flag statistical outliers (>60s stops, almost always non-strategic — drive-through penalties, damage repairs) into `IsAnomalousStop` so strategy-timing KPIs can optionally exclude them

## `lap_times`
- Convert `time` string to milliseconds using the shared `fnParseLapTime` function
- This table is left ungrouped at load (one row per lap) but staged into `FactLapTimes` with only the columns needed for pace visuals, to control model size — this is the largest table by row count and the main determinant of refresh time

## `status`
- Map the ~130 raw status strings into `StatusCategory` (Finished, Mechanical DNF, Accident, Driver Error, Other) via a maintained lookup table — this single transformation is what makes the entire Reliability & Risk page (Page 7) possible

## Refresh Performance Notes
- Query folding isn't available (flat file source), so heavy transformations are pushed as early as possible in each query and redundant steps are consolidated to minimize the number of full table scans Power Query performs
- `lap_times` and `pit_stops` are loaded as separate queries with "Enable load" off for any intermediate staging queries, so only the final shaped tables hit the data model
