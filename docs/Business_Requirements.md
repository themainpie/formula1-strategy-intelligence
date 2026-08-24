# Business Requirements Document
## Formula 1 Strategy Intelligence Platform

---

## 1. Purpose

This document defines the business case, stakeholders, and analytical requirements for the Formula 1 Strategy Intelligence Platform. It is the reference point every dashboard page, KPI, and DAX measure is built to satisfy — no chart exists in this project without a question from this document behind it.

## 2. Stakeholders & Decisions Supported

| Stakeholder | Decisions Supported |
|---|---|
| **Team Principal** | Where to invest budget/development; season trajectory vs. rivals; driver line-up decisions |
| **Sporting Director** | Championship points strategy, penalty/regulation risk, reliability exposure |
| **Strategy Department** | Pit windows, undercut/overcut timing, tire compound choice per circuit |
| **Race Engineers** | Driver-specific pace trends, consistency, setup feedback loop |
| **Performance Engineers** | Sector/pace competitiveness vs. grid, car development priorities |

## 3. Expected Business Value

- Reduce strategy decision latency during a race weekend by centralizing historical pit/undercut data by circuit
- Remove bias from driver evaluation by separating car performance from driver performance
- Surface reliability risk earlier in the season, before it costs championship points
- Provide a single source of truth for season and historical trend reporting to leadership

---

## 4. Business Questions (50)

### Race Outcomes & Championship
1. Which qualifying positions have the highest probability of converting to a race win?
2. Which constructors gain the most positions between qualifying and the finish?
3. Which drivers most consistently outperform their teammates over a season?
4. Which teams maximize championship points despite below-average qualifying pace?
5. How does championship position at mid-season correlate with final standing?
6. Which drivers have the highest podium conversion rate from a top-5 grid slot?
7. What is each constructor's win rate when leading after Lap 1?
8. Which drivers gain the most positions on the opening lap, on average?
9. How often does the pole-sitter win the race, by season era (e.g., pre/post-2010)?
10. Which constructors show the steepest points trajectory improvement within a season?

### Qualifying Intelligence
11. Which drivers have the best qualifying-to-race grid conversion rate?
12. Which circuits show the smallest gap between Q3 pace and race pace?
13. How often does a front-row qualifier fail to finish on the podium?
14. Which drivers are strongest in Q1/Q2 elimination rounds specifically?
15. What is the historical correlation between grid position and finishing position, by circuit?

### Pit Stop & Strategy
16. Which circuits reward aggressive (multi-stop) pit strategies?
17. Which teams have the fastest average pit stop times, and how has this changed year over year?
18. What is the optimal pit window (lap range) for each circuit based on historical data?
19. Which constructors most consistently execute sub-3-second pit stops?
20. How much time does an average undercut gain at each circuit?
21. Which circuits have the highest rate of pit-stop-related position losses (slow stops)?
22. Do one-stop or two-stop strategies produce better average finishing position at each circuit?
23. Which teams show the most pit stop time variance (least consistent execution)?

### Driver Performance
24. Which drivers show the most consistent lap times (lowest lap-time variance) relative to the field?
25. Which drivers most frequently set the fastest lap of the race?
26. How does driver performance trend across a career (age curve)?
27. Which drivers perform best in wet-weather races relative to their dry-race average?
28. Which rookie drivers most closely matched an experienced teammate in their debut season?
29. Which drivers have the highest rate of finishing races they started (reliability-adjusted)?
30. Which drivers gain the most positions per race on average?

### Constructor Performance
31. Which constructors have the best points-per-dollar-equivalent efficiency (points per race entered)?
32. Which constructors show the most stable performance across different circuit types (street, high-speed, technical)?
33. Which constructors have improved the most over a 3-year rolling window?
34. How does a constructor's home-race performance compare to their season average?
35. Which constructor pairings (driver lineups) produced the most combined points?

### Reliability & Risk
36. Which constructors have the highest DNF rate, and what are the leading causes?
37. Which circuits produce the highest mechanical failure rate?
38. How has reliability (finish rate) trended across the last 10 seasons league-wide?
39. Which drivers are involved in the most race-ending incidents relative to laps completed?
40. What is the average championship points cost of a DNF, by season?

### Circuit Intelligence
41. Which circuits have the highest overtaking rates (position changes per race)?
42. Which circuits most reward qualifying pace over race craft (low overtaking, pole-heavy)?
43. Which circuits produce the most frequent safety car periods, and how does that affect strategy variance?
44. Which circuits show the largest gap between fastest and slowest constructor lap times (competitive spread)?
45. Which circuits have historically been the most "unpredictable" (lowest correlation between grid and finish)?

### Season & Trend Analysis
46. How has the average field competitive gap (fastest to slowest) changed over the last decade?
47. Which era of regulation change most disrupted the competitive order?
48. Which constructors have sustained top-3 championship finishes the longest?
49. What is the average number of different race winners per season, and is parity increasing or decreasing?
50. Which drivers have had the longest sustained peak performance windows (3+ consecutive high-performing seasons)?

---

## 5. Functional Requirements

- The model must support filtering by season, circuit, driver, and constructor simultaneously without performance degradation
- All KPIs must be calculable at both season-level and career-level grain
- The report must support drillthrough from any summary visual to a driver- or constructor-level detail page
- Reliability metrics must distinguish between driver-caused and mechanical-caused DNFs where the source data allows it
- The model must support historical trend analysis across the full available season range in the dataset

## 6. Non-Functional Requirements

- Report load time under 5 seconds on a standard dataset refresh
- Data model documented well enough that a new analyst could extend it without reverse-engineering relationships
- All DAX measures named and organized into display folders (Time Intelligence, Ranking, Efficiency, Reliability, etc.)
