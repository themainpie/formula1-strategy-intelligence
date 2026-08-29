PRAGMA foreign_keys = ON;

-- ============================================================
-- DIMENSION: Drivers
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_driver (
    driver_id TEXT PRIMARY KEY,
    full_name TEXT,
    driver_code TEXT,
    nationality TEXT,
    date_of_birth DATE
);


-- ============================================================
-- DIMENSION: Constructors
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_constructor (
    constructor_id TEXT PRIMARY KEY,
    constructor_name TEXT,
    nationality TEXT
);


-- ============================================================
-- DIMENSION: Circuits
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_circuit (
    circuit_id TEXT PRIMARY KEY,
    circuit_name TEXT,
    country TEXT,
    location TEXT,
    circuit_type TEXT
);


-- ============================================================
-- DIMENSION: Races
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_race (
    race_id INTEGER PRIMARY KEY,
    circuit_id TEXT NOT NULL,
    season INTEGER,
    round INTEGER,
    race_name TEXT,
    race_date DATE,

    FOREIGN KEY (circuit_id)
        REFERENCES dim_circuit(circuit_id)
);


-- ============================================================
-- DIMENSION: Status
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_status (
    status_id INTEGER PRIMARY KEY,
    status_description TEXT,
    status_category TEXT
);


-- ============================================================
-- FACT: Race Results
-- ============================================================
CREATE TABLE IF NOT EXISTS fact_race_results (
    result_sk INTEGER PRIMARY KEY,

    race_id INTEGER NOT NULL,
    driver_id TEXT NOT NULL,
    constructor_id TEXT NOT NULL,
    status_id INTEGER,

    grid_position INTEGER,
    finish_position INTEGER,
    points REAL,
    laps_completed INTEGER,

    FOREIGN KEY (race_id)
        REFERENCES dim_race(race_id),

    FOREIGN KEY (driver_id)
        REFERENCES dim_driver(driver_id),

    FOREIGN KEY (constructor_id)
        REFERENCES dim_constructor(constructor_id),

    FOREIGN KEY (status_id)
        REFERENCES dim_status(status_id)
);


-- ============================================================
-- FACT: Pit Stops
-- ============================================================
CREATE TABLE IF NOT EXISTS fact_pit_stops (
    race_id INTEGER NOT NULL,
    driver_id TEXT NOT NULL,
    stop_number INTEGER NOT NULL,

    lap INTEGER,
    duration_ms INTEGER,

    PRIMARY KEY (race_id, driver_id, stop_number),

    FOREIGN KEY (race_id)
        REFERENCES dim_race(race_id),

    FOREIGN KEY (driver_id)
        REFERENCES dim_driver(driver_id)
);


-- ============================================================
-- FACT: Lap Times
-- ============================================================
CREATE TABLE IF NOT EXISTS fact_lap_times (
    race_id INTEGER NOT NULL,
    driver_id TEXT NOT NULL,
    lap_number INTEGER NOT NULL,

    position INTEGER,
    lap_time_ms INTEGER,

    PRIMARY KEY (race_id, driver_id, lap_number),

    FOREIGN KEY (race_id)
        REFERENCES dim_race(race_id),

    FOREIGN KEY (driver_id)
        REFERENCES dim_driver(driver_id)
);