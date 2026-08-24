# Python Analytics Plan
## Formula 1 Strategy Intelligence Platform

Python's role in this project is everything that happens **before** Power BI: cleaning, feature engineering, and the handful of analyses that are genuinely better suited to Python than DAX (clustering, outlier detection, forecasting). None of this duplicates what Power Query already does — it's the analytical layer, not the shaping layer.

Three notebooks, matching the repo structure:

---

## `etl.ipynb`

- Load all raw CSVs, profile each (`df.info()`, null counts, duplicate checks) before any transformation — this profiling output becomes the evidence base for the Power Query transformation decisions documented in `docs/Power_Query_Transformations.md`.
- Standardize the `\N` placeholder-null pattern across all files into proper `NaN`.
- Parse all lap-time and duration string formats (`mm:ss.SSS`, `+5.291s`) into consistent millisecond integers — the same logic later reused in M, but validated here first against a much easier debugging environment.
- Export cleaned tables to Parquet (not CSV) for the Power BI load — smaller, faster, and preserves data types, avoiding the "numbers stored as text" class of bug entirely.

## `feature_engineering.ipynb`

Features engineered here and exported into the Parquet layer for Power BI to consume directly (rather than recomputed in DAX, where it would be significantly slower):

- **`CircuitType`** classification (Street / Permanent / Hybrid) — done in Python via a maintained lookup rather than DAX, since it's a one-time categorical assignment, not something that needs to recalculate per filter context.
- **`StatusCategory`** grouping of the ~130 raw status strings into Finished / Mechanical / Accident / Driver Error / Other, using a mapping dictionary — same output as the Power Query version, but this notebook is where that mapping was actually built and validated against value counts.
- **Teammate pairing** — for every driver-season, identify their constructor teammate(s) and compute a `TeammatePointsDelta` and `TeammateQualifyingDelta` column, handling mid-season driver changes.
- **Stint length** — derive from `pit_stops` + `lap_times`: for each driver-race, the lap ranges between stops, feeding the tire-strategy analysis on Dashboard Page 6.
- **Rolling form features** — 5-race rolling average points and positions gained, computed and validated here before being re-expressed as DAX time-intelligence measures (measures #39–41) for interactive use in the report.

## `advanced_analytics.ipynb`

The analyses below are things DAX genuinely cannot do well, which is why they belong in Python and get exported as static results/flags feeding the model, rather than attempted as dashboard-native calculations:

1. **Driver clustering (K-Means)** — cluster driver-seasons on features like avg. grid position, avg. finish position, DNF rate, and points-per-race, to surface natural groupings (e.g., "front-runners," "midfield consistent," "high-variance backmarkers") without hand-coding thresholds. Output: a `DriverClusterID` feeding a Power BI segmentation slicer.
2. **Pit stop clustering** — cluster pit stops by duration and lap number to identify "strategic window" clusters per circuit, which is more robust than a single-average pit window and directly informs KPI #17 (Average Pit Window Variance).
3. **Outlier detection (IQR / isolation forest)** — flag anomalous pit stops (>60s, likely penalties or damage) and anomalous lap times (likely safety car laps) so these don't distort pace/degradation measures. Exported as `IsAnomalousStop` / `IsAnomalousLap` boolean flags.
4. **Regression — reliability drivers** — logistic regression predicting DNF probability from constructor, circuit, and season, to sanity-check the DAX-level `Mechanical DNF Rate` findings against a model that controls for multiple factors simultaneously rather than one slicer at a time.
5. **Forecasting — season points trajectory** — simple time-series projection (e.g., Holt-Winters or a basic linear trend on rolling form) to project a driver/constructor's likely final points total from a partial season, shown as a "projected finish" reference line on Page 1.
6. **Race pace/degradation analysis** — fit a linear slope to each driver's stint lap times to quantify tire degradation rate per stint, exported as `DegradationSlope` and consumed directly by Page 6.
7. **Strategy simulation (undercut/overcut expected value)** — a simplified Monte Carlo model estimating expected position change from pitting N laps earlier/later than a rival, parameterized per circuit using the historical undercut-gain data from `analytical_queries.sql` Q6. This is the most "senior" piece of the project — it goes beyond describing history into a light simulation model, which is what separates this from a standard reporting dashboard.

## Libraries

`pandas`, `numpy` — cleaning and feature engineering
`scikit-learn` — clustering (KMeans), regression (LogisticRegression), isolation forest
`statsmodels` or `scipy.stats` — correlation validation, regression diagnostics
`matplotlib` / `seaborn` — exploratory plots during development (not shipped in the final report, but kept in the notebook to show the analytical process)

## Why This Split Between Python and DAX

Anything that needs to **respond interactively to a slicer** belongs in DAX (rates, rankings, time intelligence). Anything that's a **one-time model fit or classification** belongs in Python and gets exported as a static column or flag. Mixing these up in either direction is a common junior mistake — trying to run a clustering algorithm in DAX, or hardcoding a rate calculation in Python that should recompute per filter context — and avoiding it is part of what this project is meant to demonstrate.
