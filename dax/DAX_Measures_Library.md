# DAX Measures Library
## Formula 1 Strategy Intelligence Platform (81 Measures)

Organized into display folders to mirror the Power BI Fields pane. The measures are designed around the report’s core data model and cover key performance, narrative, comparison, charting, and visualization needs. Additional measures were added iteratively to address gaps identified during report development, improve accuracy, provide more precise chart bindings, and support native visual techniques where needed. The folder structure at the end reflects the final organization.

---

## Folder: Core Results

```dax
1. Total Races =
DISTINCTCOUNT ( FactRaceResults[RaceID] )
// Base count used as a denominator across nearly every rate KPI.

2. Total Wins =
CALCULATE ( COUNTROWS ( FactRaceResults ), FactRaceResults[IsWin] = TRUE )

3. Total Podiums =
CALCULATE ( COUNTROWS ( FactRaceResults ), FactRaceResults[IsPodium] = TRUE )

4. Total Points =
SUM ( FactRaceResults[Points] )

5. Win Rate =
DIVIDE ( [Total Wins], [Total Races] )
// KPI #1. DIVIDE used everywhere instead of "/" to auto-handle blank denominators safely.

6. Podium Rate =
DIVIDE ( [Total Podiums], [Total Races] )
// KPI #2.

7. Points per Race =
DIVIDE ( [Total Points], [Total Races] )
// KPI #3.
```

## Folder: Championship & Ranking

```dax
8. Max Possible Points =
[Total Races] * 25
// Simplified constant (win value); documented as an approximation since points-per-position
// changed across eras — a full version would join a PointsSystem table keyed by season.

9. Championship Efficiency =
DIVIDE ( [Total Points], [Max Possible Points] )
// KPI #4.

10. Driver Championship Rank =
RANKX (
    ALL ( DimDriver[FullName] ),
    CALCULATE ( [Total Points] ),
    ,
    DESC,
    DENSE
)
// Used on Page 1 ranked bar and Page 2 driver selector context.

11. Constructor Championship Rank =
RANKX (
    ALL ( DimConstructor[ConstructorName] ),
    CALCULATE ( [Total Points] ),
    ,
    DESC,
    DENSE
)

12. Points Rank Within Season =
RANKX (
    ALLSELECTED ( DimDriver[FullName] ),
    [Total Points],
    ,
    DESC,
    DENSE
)
// ALLSELECTED (not ALL) so this respects the season slicer while still ranking across drivers.

13. Percentile Rank (Points) =
VAR CurrentPoints = [Total Points]
VAR AllPoints =
    ALL ( DimDriver[FullName] )
RETURN
DIVIDE (
    COUNTX ( AllPoints, CALCULATE ( [Total Points] ) < CurrentPoints ),
    COUNTROWS ( AllPoints )
)
// Feeds a percentile-based conditional formatting rule on ranking tables.
```

## Folder: Consistency & Race-Craft

```dax
14. Avg Finish Position =
AVERAGE ( FactRaceResults[FinishPosition] )

15. StdDev Finish Position =
STDEV.P ( FactRaceResults[FinishPosition] )

16. Driver Consistency Score =
1 - DIVIDE ( [StdDev Finish Position], [Avg Finish Position] )
// KPI #5. Bounded roughly 0-1; higher = more consistent finisher relative to their own average.

17. Avg Grid Improvement =
AVERAGEX (
    FactRaceResults,
    FactRaceResults[GridPosition] - FactRaceResults[FinishPosition]
)
// KPI #8. Positive = gains positions on race day, on average.

18. Total Positions Gained =
SUMX (
    FactRaceResults,
    FactRaceResults[GridPosition] - FactRaceResults[FinishPosition]
)

19. Overtake Rate =
DIVIDE ( [Total Positions Gained], [Total Races] )
// KPI #11 (approximation of net position change per race; a full overtake count
// would require lap-by-lap position-change detection from FactLapTimes).

20. Fastest Lap Count =
CALCULATE ( COUNTROWS ( FactRaceResults ), FactRaceResults[FastestLapRank] = 1 )

21. Fastest Lap Percentage =
DIVIDE ( [Fastest Lap Count], [Total Races] )
// KPI #9.
```

## Folder: Qualifying

```dax
22. Avg Grid Position =
AVERAGE ( FactRaceResults[GridPosition] )
// Actual starting position (post-penalty). Use this for race-day/start-of-race context.

22b. Avg Qualifying Position =
AVERAGE ( FactQualifying[QualifyingPosition] )
// Raw one-lap Saturday result (pre-penalty). Use this for pure pace comparisons —
// see the GridPosition vs QualifyingPosition distinction in docs/Data_Dictionary.md.

23. Front Row Starts =
CALCULATE ( COUNTROWS ( FactRaceResults ), FactRaceResults[GridPosition] <= 2 )
// Deliberately Grid-based, not Qualifying-based: this is about who actually lines up
// on the front row Sunday morning, which is a race-start reality, not a pace measure.

24. Front Row to Podium Conversion =
VAR FrontRowRaces =
    CALCULATETABLE ( FactRaceResults, FactRaceResults[GridPosition] <= 2 )
VAR FrontRowPodiums =
    COUNTROWS ( FILTER ( FrontRowRaces, FactRaceResults[IsPodium] = TRUE ) )
RETURN
DIVIDE ( FrontRowPodiums, COUNTROWS ( FrontRowRaces ) )
// KPI #10 (Qualifying Conversion Rate). Grid-based per the KPI's own definition —
// this is about converting an actual starting position, not raw qualifying pace.

25. Pole Positions =
CALCULATE ( COUNTROWS ( FactQualifying ), FactQualifying[QualifyingPosition] = 1 )
// FIXED: was FactRaceResults[GridPosition] = 1, which undercounts any driver who
// qualified P1 but was demoted by a grid penalty before Sunday. Pole is a qualifying-
// session record, independent of what the grid ends up looking like — must come
// from FactQualifying, not FactRaceResults.

26. Pole to Win Rate =
VAR PoleGridDrivers =
    CALCULATETABLE (
        SUMMARIZE ( FactQualifying, FactQualifying[RaceID], FactQualifying[DriverID] ),
        FactQualifying[QualifyingPosition] = 1
    )
VAR PoleRaceCount = COUNTROWS ( PoleGridDrivers )
VAR PoleWins =
    CALCULATE (
        COUNTROWS ( FactRaceResults ),
        FactRaceResults[IsWin] = TRUE,
        TREATAS ( PoleGridDrivers, FactRaceResults[RaceID], FactRaceResults[DriverID] )
    )
RETURN
DIVIDE ( PoleWins, PoleRaceCount )
// FIXED: was filtering FactRaceResults[GridPosition] = 1 entirely within FactRaceResults,
// which has the same pole-vs-grid problem as #25 above. FactQualifying and
// FactRaceResults are NOT directly related (see docs/Data_Dictionary.md — fact tables
// only connect through DimRace/DimDriver, never to each other), so "did the pole-sitter
// go on to win" genuinely requires bridging two fact tables. TREATAS pushes the
// RaceID+DriverID pairs that got pole from FactQualifying across as a virtual filter
// on FactRaceResults — this is the correct pattern any time a measure needs to combine
// facts from two tables that don't have a relationship between them.

27. Grid-to-Finish Correlation =
VAR AvgGrid = [Avg Grid Position]
VAR AvgFinish = [Avg Finish Position]
VAR Numerator =
    SUMX (
        FactRaceResults,
        ( FactRaceResults[GridPosition] - AvgGrid ) * ( FactRaceResults[FinishPosition] - AvgFinish )
    )
VAR DenomGrid =
    SUMX ( FactRaceResults, ( FactRaceResults[GridPosition] - AvgGrid ) ^ 2 )
VAR DenomFinish =
    SUMX ( FactRaceResults, ( FactRaceResults[FinishPosition] - AvgFinish ) ^ 2 )
RETURN
DIVIDE ( Numerator, SQRT ( DenomGrid * DenomFinish ) )
// SIMPLIFIED: the original version filtered VALUES(FactRaceResults[ResultSK]) and then
// referenced other FactRaceResults columns inside SUMX — this actually works in DAX
// (column-derived tables retain lineage back to their source table when the column is a
// unique key), but it's needlessly indirect and easy to misread as broken. Iterating
// FactRaceResults directly does the same thing more legibly, with identical results.
// Power BI has no native CORR(); this is the manual covariance/std-dev formula.
// KPI #19. Powers the Page 4 circuit heatmap.
```

## Folder: Reliability & Risk

```dax
28. Total DNFs =
CALCULATE ( COUNTROWS ( FactRaceResults ), FactRaceResults[IsDNF] = TRUE )

29. DNF Rate =
DIVIDE ( [Total DNFs], [Total Races] )
// KPI #13.

30. Mechanical DNFs =
CALCULATE (
    COUNTROWS ( FactRaceResults ),
    FactRaceResults[IsDNF] = TRUE,
    DimStatus[StatusCategory] = "Mechanical"
)

31. Mechanical DNF Rate =
DIVIDE ( [Mechanical DNFs], [Total Races] )
// KPI #26.

32. Constructor Reliability =
1 - DIVIDE ( [Mechanical DNFs], [Total Races] )
// KPI #6. Deliberately excludes accident/driver-error DNFs from the denominator's
// numerator so this isolates car-caused reliability specifically.

33. Expected Points If Finished =
AVERAGEX (
    FILTER ( FactRaceResults, FactRaceResults[FinishPosition] <= 10 ),
    FactRaceResults[Points]
)
// FIXED: the original iterated FILTER(ALL(FactRaceResults[FinishPosition]), ...) — a
// table of only ~10 distinct position VALUES — and averaged the [Total Points] MEASURE
// per position. That computes the average of ten highly-aggregated sums (total points
// scored league-wide by everyone who ever finished P1, P2, etc.), which is not a
// meaningful "expected points for a driver who avoided a DNF." This version iterates
// actual result rows with FinishPosition <= 10 and averages the row-level Points column
// directly — the average points value of a single top-10 finish, which is what "Expected
// Points If Finished" is supposed to represent.
// Simplified proxy for "what a mid-pack finish would have scored" — feeds Points Cost of DNF.

34. Points Cost of DNF =
[Total DNFs] * [Expected Points If Finished]
// KPI #27. An estimate, documented as such — real modeling would use each driver's
// pre-DNF running position rather than a flat average.

35. Season Parity Index =
VAR DistinctWinners =
    CALCULATE (
        DISTINCTCOUNT ( FactRaceResults[DriverID] ),
        FactRaceResults[IsWin] = TRUE
    )
RETURN
DIVIDE ( DistinctWinners, [Total Races] )
// KPI #29.
```

## Folder: Time Intelligence

**Model prerequisite — read before using #36/#37/#40:** `TOTALYTD`, `SAMEPERIODLASTYEAR`, and `DATESINPERIOD` are built-in DAX time intelligence functions, and all of them require a genuine contiguous calendar table (one row per calendar day, no gaps) marked as a Date Table in Power BI. `DimRace` only has one row per race weekend — roughly 20-24 rows per season — so it cannot serve this role; using `DimRace[Date]` directly with these functions will silently return wrong results rather than erroring, which makes it an easy bug to miss. **Add a separate `DimDate` calendar table** (`CALENDAR(MIN(DimRace[Date]), MAX(DimRace[Date]))` or `CALENDARAUTO()`), mark it as the model's Date Table, and relate `DimDate[Date]` → `DimRace[Date]` (one-to-many, DimDate is the "one" side). The measures below assume that table exists and use `DimDate[Date]` accordingly.

```dax
36. Points YTD =
TOTALYTD ( [Total Points], DimDate[Date] )
// FIXED: was TOTALYTD([Total Points], DimRace[Date]) — see the model prerequisite
// note above. Requires DimDate to exist and be marked as the Date Table.

37. Points Prior Season =
CALCULATE ( [Total Points], SAMEPERIODLASTYEAR ( DimDate[Date] ) )
// FIXED: same DimRace[Date] → DimDate[Date] correction as #36.

38. Points YoY Change % =
DIVIDE ( [Total Points] - [Points Prior Season], [Points Prior Season] )

39. Rolling 5-Race Points Avg =
VAR CurrentRaceDate = MAX ( DimRace[Date] )
VAR Last5Races =
    TOPN (
        5,
        FILTER ( ALL ( DimRace[Date] ), DimRace[Date] <= CurrentRaceDate ),
        DimRace[Date],
        DESC
    )
RETURN
CALCULATE ( AVERAGE ( FactRaceResults[Points] ), Last5Races )
// This one is fine as-is on DimRace[Date] — TOPN/FILTER are ordinary table functions,
// not time intelligence functions, so they don't need a contiguous calendar. No fix
// needed here; included for contrast with #36/#37/#40 above/below.
// Drives the Page 1/Page 2 momentum trend line.

40. Rolling 3-Season Avg Finish =
CALCULATE (
    [Avg Finish Position],
    DATESINPERIOD ( DimDate[Date], MAX ( DimDate[Date] ), -3, YEAR )
)
// FIXED: was DATESINPERIOD(DimRace[Date], ...) — same calendar-table requirement as
// #36/#37. Also removed an unused `CurrentSeason` variable that was never referenced
// in the original — dead code, not a functional bug, but cleaned up here.

41. Development Trajectory Score =
VAR ThisSeasonAvg = [Avg Finish Position]
VAR ThreeSeasonsAgoAvg =
    CALCULATE (
        [Avg Finish Position],
        DimRace[Season] = MAX ( DimRace[Season] ) - 3
    )
RETURN
ThreeSeasonsAgoAvg - ThisSeasonAvg
// Fine as-is: DimRace[Season] = <value> is an ordinary equality filter, not a time
// intelligence function, so it doesn't need DimDate.
// KPI #30. Positive = finishing position has improved (lower number) over 3 seasons.
```

## Folder: Pit Stop & Strategy

```dax
42. Avg Pit Stop Duration (s) =
DIVIDE ( AVERAGE ( FactPitStops[DurationMs] ), 1000 )

43. Field Median Pit Stop Duration (s) =
DIVIDE (
    MEDIANX ( ALL ( FactPitStops ), FactPitStops[DurationMs] ),
    1000
)

44. Pit Stop Efficiency (Delta vs Field) =
[Avg Pit Stop Duration (s)] - [Field Median Pit Stop Duration (s)]
// KPI #7. Negative = faster than the field median (good).

45. Pit Stop Duration StdDev =
DIVIDE ( STDEV.P ( FactPitStops[DurationMs] ), 1000 )
// This measures EXECUTION variance (how consistent the crew's stop times are), not
// STRATEGIC WINDOW variance — see #45b below for KPI #17, which was previously
// (incorrectly) attributed to this measure.

45b. Pit Window Variance (Lap) =
STDEV.P ( FactPitStops[Lap] )
// FIXED / ADDED: KPI #17 (Average Pit Window Variance) is defined as "StdDev of Pit
// Stop Lap by Circuit" — i.e. how spread out the LAP NUMBER stops happen on, which
// tells you how predictable/exploitable a circuit's pit window is. #45 above measures
// STDEV of DurationMs (how long the stop takes), which is a completely different thing
// and was incorrectly cited as feeding KPI #17. This measure uses FactPitStops[Lap]
// instead, which is what KPI #17 actually asks for. Apply at circuit-level grain
// (filtered by DimCircuit) for the intended use on Dashboard Page 5.

46. Total Pit Stops =
COUNTROWS ( FactPitStops )

47. Avg Stops per Race =
DIVIDE ( [Total Pit Stops], [Total Races] )

48. Multi-Stop Race Win Rate =
VAR StopCounts =
    SUMMARIZE (
        FactPitStops,
        FactPitStops[RaceID], FactPitStops[DriverID],
        "StopCount", COUNTROWS ( FactPitStops )
    )
VAR MultiStopKeys =
    FILTER ( StopCounts, [StopCount] >= 2 )
VAR MultiStopRaceResults =
    CALCULATETABLE (
        FactRaceResults,
        TREATAS ( MultiStopKeys, FactRaceResults[RaceID], FactRaceResults[DriverID] )
    )
RETURN
DIVIDE (
    COUNTROWS ( FILTER ( MultiStopRaceResults, FactRaceResults[IsWin] = TRUE ) ),
    COUNTROWS ( MultiStopRaceResults )
)
// FIXED: the original filtered FactRaceResults using
// FILTER(FactRaceResults, CALCULATE(COUNTROWS(FactPitStops)) >= 2) — but FactPitStops
// and FactRaceResults have no direct relationship (see docs/Data_Dictionary.md: fact
// tables only connect through DimRace/DimDriver). Row-context transition on
// FactRaceResults only propagates through an ACTIVE relationship; since there isn't
// one straight to FactPitStops, COUNTROWS(FactPitStops) would evaluate the same for
// every row instead of per race-driver, making the filter meaningless. This version
// builds the RaceID+DriverID pairs with 2+ stops directly from FactPitStops via
// SUMMARIZE, then bridges them onto FactRaceResults with TREATAS — the same pattern
// used to fix Pole to Win Rate (#26) above.
// KPI #28.
```

## Folder: Dynamic Titles & UX

```dax
49. Dynamic Page Title (Driver Focus) =
VAR SelectedDriver =
    IF ( HASONEVALUE ( DimDriver[FullName] ), VALUES ( DimDriver[FullName] ), "Selected Drivers" )
VAR SelectedSeason =
    IF ( HASONEVALUE ( DimRace[Season] ), FORMAT ( VALUES ( DimRace[Season] ), "0" ), "All Seasons" )
RETURN
SelectedDriver & " — " & SelectedSeason & " Performance Summary"
// Used as the title text box on Page 2, re-evaluates with every slicer change.

50. Insight Narrative (Strongest Circuit Type) =
VAR BestCircuitType =
    TOPN (
        1,
        SUMMARIZE (
            FactRaceResults,
            DimCircuit[CircuitType],
            "AvgFinish", [Avg Finish Position]
        ),
        [AvgFinish], ASC
    )
RETURN
"Strongest at " & CONCATENATEX ( BestCircuitType, DimCircuit[CircuitType] ) & " circuits this season."
// Powers the driver-focused insight text box on Page 2 (Driver Performance).

53. Executive Insight Narrative =
VAR LeaderTable =
    TOPN ( 1, ALLSELECTED ( DimDriver[FullName] ), CALCULATE ( [Total Points] ), DESC )
VAR LeaderName = MAXX ( LeaderTable, DimDriver[FullName] )
VAR LeaderPoints = MAXX ( LeaderTable, CALCULATE ( [Total Points] ) )
VAR SecondTable =
    TOPN (
        1,
        FILTER ( ALLSELECTED ( DimDriver[FullName] ), DimDriver[FullName] <> LeaderName ),
        CALCULATE ( [Total Points] ), DESC
    )
VAR SecondName = MAXX ( SecondTable, DimDriver[FullName] )
VAR SecondPoints = MAXX ( SecondTable, CALCULATE ( [Total Points] ) )
VAR PointsGap = LeaderPoints - SecondPoints
VAR LeaderWinRate = CALCULATE ( [Win Rate], DimDriver[FullName] = LeaderName )
VAR LeaderRecentForm = CALCULATE ( [Rolling 5-Race Points Avg], DimDriver[FullName] = LeaderName )
VAR LeaderSeasonAvg = CALCULATE ( DIVIDE ( [Total Points], [Total Races] ), DimDriver[FullName] = LeaderName )
VAR MomentumText =
    SWITCH (
        TRUE (),
        ISBLANK ( LeaderRecentForm ) || ISBLANK ( LeaderSeasonAvg ), "",
        LeaderRecentForm > LeaderSeasonAvg * 1.15, " Form is trending upward over the last 5 races.",
        LeaderRecentForm < LeaderSeasonAvg * 0.85, " Form has cooled off over the last 5 races.",
        " Form has held steady over the last 5 races."
    )
VAR GapText =
    SWITCH (
        TRUE (),
        ISBLANK ( SecondName ), "with no rival yet in view",
        PointsGap >= 50, "a commanding " & FORMAT ( PointsGap, "0" ) & "-point lead over " & SecondName,
        PointsGap >= 15, "a solid " & FORMAT ( PointsGap, "0" ) & "-point lead over " & SecondName,
        PointsGap > 0, "a narrow " & FORMAT ( PointsGap, "0" ) & "-point edge over " & SecondName,
        "a title fight tied at the top with " & SecondName
    )
RETURN
IF (
    ISBLANK ( LeaderPoints ),
    "No results yet for the current selection.",
    LeaderName & " leads with " & FORMAT ( LeaderPoints, "0" ) & " points, holding " & GapText
        & " (" & FORMAT ( LeaderWinRate, "0%" ) & " win rate)." & MomentumText
)
// Powers the Page 1 (Executive Overview) insight text box — see docs/Dashboard_Design.md.
// Built entirely from existing measures (#7 Total Points, #5 Win Rate, #39 Rolling
// 5-Race Points Avg) rather than new logic, so it stays consistent if any of those are
// retuned later. ALLSELECTED (not ALL) keeps this respecting the Season slicer while
// still ranking across the full driver field, same pattern as #12. Two defensive
// guards worth noting: the outer IF(ISBLANK(...)) handles an empty selection (e.g. a
// season with no results loaded yet), and the SecondName ISBLANK check inside GapText
// handles the case where a driver slicer narrows the field to a single driver, at
// which point "gap to second" has no meaning.
```

---

## Folder: Pace & Performance (added — see note at top of file)

```dax
51. Avg Race Pace (%) =
AVERAGEX (
    FactLapTimes,
    DIVIDE (
        FactLapTimes[LapTimeMs],
        CALCULATE ( MIN ( FactLapTimes[LapTimeMs] ), ALLEXCEPT ( FactLapTimes, FactLapTimes[RaceID] ) )
    )
) * 100
// KPI #12. For each lap, divides that lap's time by the fastest lap set IN THAT SAME RACE
// (ALLEXCEPT keeps the RaceID filter from row-context transition but clears everything
// else, so "fastest lap this race" is computed correctly regardless of which driver/lap
// is currently in context), then averages across all laps in the current filter. Result
// is a percentage: 100% = exactly as fast as the race's fastest lap, 105% = 5% off it.
// This is genuinely a rate, not a raw average of LapTimeMs, which is why a straight
// AVERAGE(FactLapTimes[LapTimeMs]) wouldn't work — lap times aren't comparable
// across circuits (a Monaco lap and a Monza lap are different units of "fast"),
// but each lap's % gap to its own race's fastest lap is.

52. Competitive Spread Index =
VAR ConstructorPaces =
    ADDCOLUMNS (
        VALUES ( DimConstructor[ConstructorName] ),
        "ConstructorAvgPace",
        VAR DriverRacePairs =
            CALCULATETABLE (
                SUMMARIZE ( FactRaceResults, FactRaceResults[RaceID], FactRaceResults[DriverID] )
            )
        RETURN
            CALCULATE (
                [Avg Race Pace (%)],
                TREATAS ( DriverRacePairs, FactLapTimes[RaceID], FactLapTimes[DriverID] )
            )
    )
VAR FastestConstructorPace = MINX ( ConstructorPaces, [ConstructorAvgPace] )
VAR SlowestConstructorPace = MAXX ( ConstructorPaces, [ConstructorAvgPace] )
RETURN
DIVIDE ( SlowestConstructorPace - FastestConstructorPace, FastestConstructorPace )
// KPI #25. Feeds Dashboard Page 3's "Competitive spread by circuit type" chart.
// FactLapTimes has no direct relationship to DimConstructor (constructor is only on
// FactRaceResults, and lap times relate to DimRace/DimDriver, not to FactRaceResults —
// see docs/Data_Dictionary.md), so this uses the same SUMMARIZE + TREATAS bridging
// pattern as #26/#48: for each constructor, pull the RaceID+DriverID pairs that drove
// for them (from FactRaceResults, via context transition on the ADDCOLUMNS row), then
// push those onto FactLapTimes to compute that constructor's average pace. Depends on
// #51 (Avg Race Pace) — build that one first.
```

---

## Folder: Teammate Comparison

**Why these exist as measures, not just raw imported columns:** `FactDriverSeasonStats[TeammatePointsDelta]` (and its Grid/Qualifying counterparts) are pre-computed in `feature_engineering.ipynb` at **one row per driver per season**. Dropped directly into a card visual without also filtering to a single season, Power BI defaults to summing the column across every season that driver appears in — and since most drivers have some seasons where they outscored their teammate and some where they didn't, those largely cancel out, producing a misleadingly near-zero number regardless of which driver you pick. The measures below guard against exactly that by returning `BLANK()` — with an explanatory message — instead of silently aggregating across seasons.

```dax
54. Teammate Points Delta =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[TeammatePointsDelta] ),
    BLANK ()
)
// FIXED / ADDED: was being used as a raw column in a card (see Page 2 in
// docs/Dashboard_Design.md, previously marked "imported feature column, not DAX").
// Without this guard, selecting a driver but not a season sums TeammatePointsDelta
// across their whole career — positive and negative seasons cancel out, which is
// almost certainly the cause of the near-zero values reported across ~20-30 drivers.
// SELECTEDVALUE returns BLANK if more than one row still matches after both filters
// (e.g. a driver who changed constructors mid-season, leaving 2 rows for one season) —
// that's a rarer edge case worth knowing about but not the main fix here.

55. Teammate Grid Delta =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[TeammateGridDelta] ),
    BLANK ()
)
// Same guard pattern as #54, applied to the grid-position teammate comparison.

56. Teammate Qualifying Delta =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[TeammateQualifyingDelta] ),
    BLANK ()
)
// Same guard pattern as #54, applied to the qualifying-pace teammate comparison
// (KPI #15) — this is the one that isolates true one-lap pace, per the
// GridPosition vs QualifyingPosition distinction elsewhere in this library.

57. Teammate Comparison Context Warning =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && NOT HASONEVALUE ( DimSeason[Season] ),
    "Select a single season to see this driver's teammate comparison — these values are season-specific and don't sum meaningfully across a career.",
    BLANK ()
)
// Optional companion measure: bind this to a text box near the teammate KPI cards on
// Page 2. Shows a warning only in the exact situation that causes the bug above
// (driver selected, season not) — silent otherwise, so it doesn't clutter the page
// once a season is selected. Cheaper than hoping every viewer remembers to also
// filter by season.

63. Selected Driver Season Points =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[SeasonPoints] ),
    BLANK ()
)

64. Selected Driver's Teammate Points =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[TeammatePoints] ),
    BLANK ()
)

65. Selected Driver Avg Qualifying Position =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[AvgQualifyingPosition] ),
    BLANK ()
)

66. Selected Driver's Teammate Avg Qualifying Position =
IF (
    HASONEVALUE ( DimDriver[DriverID] ) && HASONEVALUE ( DimSeason[Season] ),
    SELECTEDVALUE ( FactDriverSeasonStats[TeammateAvgQualifyingPosition] ),
    BLANK ()
)
// #63-66 are the raw building blocks for the Page 2 "Teammate head-to-head" chart —
// each is a guarded SELECTEDVALUE off FactDriverSeasonStats, same season/driver guard
// pattern as #54-57. On their own they're not chart-ready (a clustered bar needs one
// axis with two category values, not two separate measures) — #67/#68 below wrap
// these into a single switchable measure using a small disconnected table.

67. Teammate Compare - Points =
SWITCH (
    SELECTEDVALUE ( TeammateCompareAxis[Role] ),
    "Selected Driver", [Selected Driver Season Points],
    "Teammate", [Selected Driver's Teammate Points],
    BLANK ()
)

68. Teammate Compare - Qualifying Position =
SWITCH (
    SELECTEDVALUE ( TeammateCompareAxis[Role] ),
    "Selected Driver", [Selected Driver Avg Qualifying Position],
    "Teammate", [Selected Driver's Teammate Avg Qualifying Position],
    BLANK ()
)
// #67/#68 require a small disconnected table called TeammateCompareAxis with a single
// text column [Role] containing exactly two rows: "Selected Driver" and "Teammate".
// Add it via Get Data -> Blank Query (same mechanism as powerbi/Additional_PowerBI_Tables.md):
//   let
//       Source = #table({"Role"}, {{"Selected Driver"}, {"Teammate"}})
//   in
//       Source
// This table has NO relationship to anything else in the model — it exists purely to
// give a clustered bar chart two axis categories to switch a measure on. Put
// TeammateCompareAxis[Role] on the chart's Axis well and #67 (or #68) on Values; the
// chart will show exactly two bars, correctly comparing whoever is currently selected
// in the DimDriver/DimSeason slicers against their teammate. This is the standard DAX
// pattern for "compare two named things side by side" when the two things being
// compared are values on the same row rather than separate rows in a table.
```

---

## Folder: Constructor Performance

```dax
62. Home Race Performance Delta =
VAR HomeCountry =
    LOOKUPVALUE ( ConstructorHomeCountry[Country], ConstructorHomeCountry[ConstructorName], SELECTEDVALUE ( DimConstructor[ConstructorName] ) )
VAR HomeRaceAvgFinish =
    CALCULATE ( [Avg Finish Position], DimCircuit[Country] = HomeCountry )
RETURN
IF (
    ISBLANK ( HomeCountry ),
    BLANK (),
    [Avg Finish Position] - HomeRaceAvgFinish
)
// KPI-adjacent measure for Page 3. Positive = performs better at home than average
// (lower finish position at the home race); negative = worse.
// REQUIRES a small manual mapping table, ConstructorHomeCountry (ConstructorName,
// Country), added the same way as ConstructorColors in
// powerbi/Additional_PowerBI_Tables.md. This can't be derived automatically:
// DimConstructor[Nationality] is a demonym string ("British", "Italian") from
// constructors.csv, and DimCircuit[Country] is a country name string ("UK", "Italy")
// from circuits.csv — these don't reliably match as text (e.g. "British" vs "UK" /
// "Great Britain"), so a manual lookup is the honest fix rather than a fragile string
// match. Populate ConstructorHomeCountry with entries for the current 10-team grid at
// minimum; historical constructors without an entry return BLANK() rather than a wrong
// number, same fallback philosophy as the color mapping.
```

---

## Folder: Report-Layer Helper Measures

Measures that exist specifically to make one chart on `docs/Dashboard_Design.md` work — several need a small disconnected table added directly in Power BI (same mechanism as `powerbi/Additional_PowerBI_Tables.md`), noted per measure.

```dax
58. Cumulative Season Points =
VAR CurrentSeason = MAX ( DimRace[Season] )
VAR CurrentRound = MAX ( DimRace[Round] )
RETURN
CALCULATE (
    [Total Points],
    ALLSELECTED ( DimRace[Round] ),
    DimRace[Season] = CurrentSeason,
    DimRace[Round] <= CurrentRound
)
// Page 1 standings line chart. Running total of points within the selected season, by
// round — ALLSELECTED(DimRace[Round]) clears the specific-round context a line chart
// puts each point in so every point can see "all rounds up to and including this one,"
// while the explicit Season/Round equality keeps it from also picking up other seasons.

59. Entered Q1 =
COUNTROWS ( FactQualifying )

60. Advanced to Q2 =
CALCULATE ( COUNTROWS ( FactQualifying ), FactQualifying[EliminatedInQ1] = FALSE )

61. Advanced to Q3 =
CALCULATE ( COUNTROWS ( FactQualifying ), FactQualifying[EliminatedInQ2] = FALSE )
// #59-61: Page 4 funnel chart stages. Drop all three directly into the funnel visual's
// Values well as separate measures (funnel charts accept multiple measures as stages
// natively) — no disconnected table needed for this one.

69. Win Rate by Stop Count Bucket =
VAR SelectedBucket = SELECTEDVALUE ( StopCountBucketAxis[Bucket] )
VAR StopCounts =
    SUMMARIZE ( FactPitStops, FactPitStops[RaceID], FactPitStops[DriverID], "StopCount", COUNTROWS ( FactPitStops ) )
VAR MatchingKeys =
    FILTER (
        StopCounts,
        SWITCH (
            TRUE (),
            SelectedBucket = "1-Stop", [StopCount] = 1,
            SelectedBucket = "2-Stop", [StopCount] = 2,
            SelectedBucket = "3+-Stop", [StopCount] >= 3,
            FALSE ()
        )
    )
VAR BucketRaceResults =
    CALCULATETABLE ( FactRaceResults, TREATAS ( MatchingKeys, FactRaceResults[RaceID], FactRaceResults[DriverID] ) )
RETURN
DIVIDE (
    COUNTROWS ( FILTER ( BucketRaceResults, FactRaceResults[IsWin] = TRUE ) ),
    COUNTROWS ( BucketRaceResults )
)
// Page 5 strategy win-rate chart. Generalizes the same SUMMARIZE + TREATAS bridging
// pattern from #48 (Multi-Stop Race Win Rate) into three selectable buckets instead of
// one fixed ">=2" threshold. REQUIRES a disconnected StopCountBucketAxis table:
//   let
//       Source = #table({"Bucket"}, {{"1-Stop"}, {"2-Stop"}, {"3+-Stop"}})
//   in
//       Source
// Put StopCountBucketAxis[Bucket] on the chart's Axis well, this measure on Values.

70. Fastest Lap Time This Lap =
CALCULATE ( MIN ( FactLapTimes[LapTimeMs] ), ALLSELECTED ( DimDriver ) )

71. Slowest Lap Time This Lap =
CALCULATE ( MAX ( FactLapTimes[LapTimeMs] ), ALLSELECTED ( DimDriver ) )
// Page 6 field pace spread area chart. With FactLapTimes[Lap] on the X-axis, these give
// the fastest/slowest lap time set by ANY driver on that lap — ALLSELECTED(DimDriver)
// deliberately ignores the page's driver multi-select (which highlights specific lines
// on the main lap-trend chart) so this spread reflects the WHOLE field regardless of
// which drivers are highlighted elsewhere on the page, while still respecting the
// Race slicer that both charts share. Plot as a band: Slowest as the area's upper
// bound, Fastest as the lower bound (Power BI area/ribbon chart with two measures).
```

---

## Folder: Distribution / Range Charts (native visual replacements)

**Why these exist:** the original spec for Page 2's consistency chart and Page 5's pit duration chart called for a box-and-whisker plot — that's not a native Power BI visual, it's a paid/AppSource custom visual, and the free ones on AppSource render rough. These measures replace it with a **floating bar chart**, built entirely from native Stacked Column + Line combo visuals: stack an invisible "base" segment (the minimum) under a visible "range" segment (max − min), then overlay the median as a line. This is a standard free-tools technique that reproduces the useful part of a box plot (spread + central tendency) without any custom visual.

```dax
72. Min Finish Position =
MIN ( FactRaceResults[FinishPosition] )

73. Max Finish Position =
MAX ( FactRaceResults[FinishPosition] )

74. Median Finish Position =
MEDIAN ( FactRaceResults[FinishPosition] )

75. Finish Position Range (Floating Bar Base) =
[Min Finish Position]

76. Finish Position Range (Floating Bar Height) =
[Max Finish Position] - [Min Finish Position]
// #72-76: Page 2 consistency chart. Stack #75 then #76 on a Stacked Column Chart with
// DimDriver[FullName] on Axis — #75's series color set to fully transparent (Format
// visual -> Data colors) makes it invisible, leaving only #76 visible as a floating
// bar spanning each driver's min-to-max finish position for the season. Add #74 via
// "Line and Stacked Column Chart" (native combo) to overlay the median as a line
// marker on the same categories.

77. Min Pit Stop Duration (s) =
DIVIDE ( MIN ( FactPitStops[DurationMs] ), 1000 )

78. Max Pit Stop Duration (s) =
DIVIDE ( MAX ( FactPitStops[DurationMs] ), 1000 )

79. Median Pit Stop Duration (s) =
DIVIDE ( MEDIAN ( FactPitStops[DurationMs] ), 1000 )

80. Pit Stop Duration Range (Floating Bar Base) =
[Min Pit Stop Duration (s)]

81. Pit Stop Duration Range (Floating Bar Height) =
[Max Pit Stop Duration (s)] - [Min Pit Stop Duration (s)]
// #77-81: Page 5 duration chart. Same floating-bar technique as #72-76, with
// DimConstructor[ConstructorName] on Axis instead of driver. #79 (median) overlays
// as the combo line, same as #74 above.
```

---

## Design Notes

- Every rate measure uses `DIVIDE()` rather than `/` to avoid divide-by-zero errors when a slicer selection produces an empty denominator (e.g., a driver with zero races in a filtered season).
- Ranking measures use `DENSE` rank so tied point totals don't skip rank numbers, matching how championship standings are actually reported.
- `ALLSELECTED` vs `ALL` is used deliberately: `ALL` for true global comparisons (percentile, career-long ranks), `ALLSELECTED` for in-context ranks that should still respect the active slicer panel.
- Approximation measures (`Max Possible Points`, `Expected Points If Finished`, `Overtake Rate`) are explicitly documented as simplified models rather than presented as precise — this is intentional: a senior reviewer will trust a project more for stating its modeling limitations than for hiding them.
- **Bridging unrelated fact tables with `TREATAS`:** `FactQualifying`, `FactPitStops`, and `FactRaceResults` deliberately have no direct relationships to each other (see `docs/Data_Dictionary.md`). Any measure that needs to combine information from two of them — "did the pole-sitter win," "did a 2+ stop race result in a win" — has to build a virtual key table from one fact table (via `SUMMARIZE`) and push it onto the other with `TREATAS`. Plain row-context transition (`CALCULATE` inside a `FILTER`/iterator) does **not** work across unrelated fact tables — it silently returns the same value for every row instead of erroring, which is what made #26 and #48 easy bugs to miss. This is the pattern to reach for any time a new measure needs to cross fact tables.
- **Time intelligence functions need a real calendar table.** `TOTALYTD`, `SAMEPERIODLASTYEAR`, `DATESINPERIOD`, and similar built-ins require a contiguous, one-row-per-day date table marked as the model's Date Table — `DimRace[Date]` (one row per race weekend) can't serve that role. Add a `DimDate` calendar table before using measures #36/#37/#40.