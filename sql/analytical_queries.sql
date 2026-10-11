-- ============================================================
-- Formula 1 Strategy Intelligence Platform
-- Analytical Query Library
-- Each query is annotated with the business question it answers
-- ============================================================

-- --------------------------------------------------------------
-- Q1. Which qualifying positions have the highest probability
--     of winning? (Business Question #1)
-- --------------------------------------------------------------
SELECT
    q.qualifying_position,
    COUNT(*) AS races_started_from_position,
    SUM(CASE WHEN f.finish_position = 1 THEN 1 ELSE 0 END) AS wins,
    ROUND(100.0 * SUM(CASE WHEN f.finish_position = 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS win_rate_pct
FROM fact_qualifying q
JOIN fact_race_results f
    ON f.race_id = q.race_id AND f.driver_id = q.driver_id
WHERE q.qualifying_position IS NOT NULL
GROUP BY q.qualifying_position
ORDER BY q.qualifying_position;
 
-- Same question on the post-penalty starting grid.
-- grid_position = 0 means no regular grid slot (e.g. pit-lane start),
-- so it is excluded to keep the win-rate table clean.
SELECT
    grid_position,
    COUNT(*) AS races_started_from_grid,
    SUM(CASE WHEN finish_position = 1 THEN 1 ELSE 0 END) AS wins,
    ROUND(100.0 * SUM(CASE WHEN finish_position = 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS win_rate_pct
FROM fact_race_results
WHERE grid_position > 0
GROUP BY grid_position
ORDER BY grid_position;

-- --------------------------------------------------------------
-- Q2. Which drivers most consistently outperform their teammates?
--     (Business Question #3) — uses a window function to pair
--     teammates within the same constructor/season
-- --------------------------------------------------------------
WITH driver_season_points AS (
    SELECT
        f.driver_id,
        f.constructor_id,
        r.season,
        SUM(f.points) AS season_points
    FROM fact_race_results f
    JOIN dim_race r ON r.race_id = f.race_id
    GROUP BY f.driver_id, f.constructor_id, r.season
),
teammate_ranked AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY constructor_id, season
            ORDER BY season_points DESC
        ) AS teammate_rank,
        COUNT(*) OVER (PARTITION BY constructor_id, season) AS drivers_in_group
    FROM driver_season_points
),
comparable_seasons AS (
    SELECT * FROM teammate_ranked WHERE drivers_in_group >= 2
)
SELECT
    driver_id,
    COUNT(*) AS seasons_with_teammate,
    SUM(CASE WHEN teammate_rank = 1 THEN 1 ELSE 0 END) AS seasons_beat_teammate,
    ROUND(100.0 * SUM(CASE WHEN teammate_rank = 1 THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS teammate_beat_rate_pct
FROM comparable_seasons
GROUP BY driver_id
HAVING COUNT(*) >= 3   -- require a meaningful sample of seasons, not one good year
ORDER BY teammate_beat_rate_pct DESC, seasons_with_teammate DESC;

-- --------------------------------------------------------------
-- Q3. Which circuits reward aggressive (multi-stop) pit strategies?
--     (Business Question #16) — CTE + join to derive stop counts
--     per driver per race, then aggregate by circuit
--
--     Restricted to the pit-stop data era (1996 onwards) and to
--     drivers who made at least one stop, so "0 stops" no longer
--     mixes missing data and early retirements with real strategies.
--     Correlation only: extra stops are often forced by incidents
--     or car pace rather than chosen.
-- --------------------------------------------------------------
WITH stops_per_race AS (
    SELECT race_id, driver_id, COUNT(*) AS stop_count
    FROM fact_pit_stops
    GROUP BY race_id, driver_id
),
result_with_stops AS (
    SELECT
        r.race_id,
        r.driver_id,
        r.finish_position,
        s.stop_count,
        dr.circuit_id
    FROM fact_race_results r
    JOIN dim_race dr ON dr.race_id = r.race_id
    JOIN stops_per_race s
        ON s.race_id = r.race_id AND s.driver_id = r.driver_id
    WHERE dr.season >= 1996            -- pit-stop data era
      AND s.stop_count >= 1
      AND r.finish_position IS NOT NULL
)
SELECT
    c.circuit_name,
    rs.stop_count,
    COUNT(*) AS sample_size,
    ROUND(AVG(rs.finish_position), 2) AS avg_finish_position
FROM result_with_stops rs
JOIN dim_circuit c ON c.circuit_id = rs.circuit_id
GROUP BY c.circuit_name, rs.stop_count
HAVING COUNT(*) >= 10                  -- suppress low-sample noise
ORDER BY c.circuit_name, rs.stop_count;

-- --------------------------------------------------------------
-- Q4. Constructor reliability (mechanical DNF rate) by circuit
--     (Business Question #37)
-- --------------------------------------------------------------
SELECT
    c.circuit_name,
    con.constructor_name,
    COUNT(*) AS races_entered,
    SUM(CASE WHEN st.status_category = 'Mechanical' THEN 1 ELSE 0 END) AS mechanical_dnfs,
    ROUND(100.0 * SUM(CASE WHEN st.status_category = 'Mechanical' THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS mechanical_dnf_rate_pct
FROM fact_race_results f
JOIN dim_race r      ON r.race_id = f.race_id
JOIN dim_circuit c   ON c.circuit_id = r.circuit_id
JOIN dim_constructor con ON con.constructor_id = f.constructor_id
JOIN dim_status st   ON st.status_id = f.status_id
GROUP BY c.circuit_name, con.constructor_name
HAVING COUNT(*) >= 10
ORDER BY mechanical_dnf_rate_pct DESC;

-- --------------------------------------------------------------
-- Q5. Position change around a driver's first pit stop
--     (Business Question #20 — undercut value) — simplified proxy,
--     see the note below on exactly what this does and doesn't measure
-- --------------------------------------------------------------
WITH pit_events AS (
    SELECT
        p.race_id,
        p.driver_id,
        p.lap,
        r.circuit_id
    FROM fact_pit_stops p
    JOIN dim_race r ON r.race_id = p.race_id
    WHERE p.stop_number = 1
),
position_before_after AS (
    SELECT
        pe.race_id,
        pe.driver_id,
        pe.circuit_id,
        lt_before.position AS position_before,
        lt_after.position  AS position_after
    FROM pit_events pe
    JOIN fact_lap_times lt_before
        ON lt_before.race_id = pe.race_id
       AND lt_before.driver_id = pe.driver_id
       AND lt_before.lap_number = pe.lap - 1
    JOIN fact_lap_times lt_after
        ON lt_after.race_id = pe.race_id
       AND lt_after.driver_id = pe.driver_id
       AND lt_after.lap_number = pe.lap + 3
)
SELECT
    c.circuit_name,
    ROUND(AVG(position_before - position_after), 2) AS avg_positions_gained_post_stop,
    COUNT(*) AS sample_size
FROM position_before_after pba
JOIN dim_circuit c ON c.circuit_id = pba.circuit_id
GROUP BY c.circuit_name
ORDER BY avg_positions_gained_post_stop DESC;

-- --------------------------------------------------------------
-- Q6a. Season parity index: distinct winners / total races per
--      season (Business Question #49)
-- --------------------------------------------------------------
SELECT
    r.season,
    COUNT(DISTINCT r.race_id) AS total_races,
    COUNT(DISTINCT CASE WHEN f.finish_position = 1 THEN f.driver_id END) AS distinct_winners,
    ROUND(1.0 * COUNT(DISTINCT CASE WHEN f.finish_position = 1 THEN f.driver_id END)
          / COUNT(DISTINCT r.race_id), 3) AS parity_index
FROM fact_race_results f
JOIN dim_race r ON r.race_id = f.race_id
GROUP BY r.season
ORDER BY r.season;
 
-- --------------------------------------------------------------
-- Q6b. Season parity index rolled up by decade
--      (Business Question #49) — builds on Q6a via a CTE.
--      The current season is excluded because it is incomplete.
-- --------------------------------------------------------------
WITH season_parity AS (
    SELECT
        r.season,
        COUNT(DISTINCT r.race_id) AS total_races,
        COUNT(DISTINCT CASE WHEN f.finish_position = 1 THEN f.driver_id END) AS distinct_winners,
        ROUND(1.0 * COUNT(DISTINCT CASE WHEN f.finish_position = 1 THEN f.driver_id END)
              / COUNT(DISTINCT r.race_id), 3) AS parity_index
    FROM fact_race_results f
    JOIN dim_race r ON r.race_id = f.race_id
    GROUP BY r.season
)
SELECT
    (CAST(season AS INTEGER) / 10) * 10 AS decade,
    COUNT(*) AS seasons_in_decade,
    SUM(total_races) AS total_races,
    ROUND(AVG(parity_index), 3) AS avg_parity_index,
    MIN(parity_index) AS lowest_parity,
    MAX(parity_index) AS highest_parity
FROM season_parity
WHERE season < 2026
GROUP BY (CAST(season AS INTEGER) / 10) * 10
ORDER BY decade;