# KPI Dictionary
## Formula 1 Strategy Intelligence Platform

Each KPI below maps to at least one business question from `Business_Requirements.md`. Grain is season-level by default; most also support career/all-time and per-race grain via slicers.

| # | KPI | Definition | Business Use |
|---|---|---|---|
| 1 | **Win Rate** | Wins ÷ Races Started | Championship-caliber performance benchmark |
| 2 | **Podium Rate** | Podiums ÷ Races Started | Consistency of front-running performance |
| 3 | **Points per Race** | Total Points ÷ Races Started | Normalizes points across drivers with different race counts |
| 4 | **Championship Efficiency** | Points Earned ÷ Maximum Possible Points | How close to a "perfect season" a driver/constructor ran |
| 5 | **Driver Consistency Score** | 1 − (StdDev of Finishing Position ÷ Mean Finishing Position) | Rewards drivers who reliably finish where their pace suggests |
| 6 | **Constructor Reliability** | Races Finished ÷ Races Started (car-caused DNFs only) | Isolates mechanical dependability from driver error |
| 7 | **Pit Stop Efficiency** | Average Pit Stop Time vs. Field Median (delta, seconds) | Operational execution benchmark for the strategy team |
| 8 | **Average Grid Improvement** | Average of (Grid Position − Finish Position) | Race-craft indicator independent of car pace |
| 9 | **Fastest Lap Percentage** | Races with Fastest Lap ÷ Races Started | Pure pace indicator, unaffected by strategy or luck |
| 10 | **Qualifying Conversion Rate** | Races Where Grid ≤ 3 and Finish ≤ 3 ÷ Races Started with Grid ≤ 3 | How reliably a front-row start becomes a podium |
| 11 | **Overtake Rate** | Average Net Position Changes per Race | Circuit and driver overtaking tendency |
| 12 | **Average Race Pace** | Mean Lap Time normalized against fastest lap of the race (%) | True competitive pace, independent of fuel/strategy laps |
| 13 | **DNF Rate** | DNFs ÷ Races Started | Headline reliability/risk indicator |
| 14 | **Teammate Delta (Points)** | Driver Points − Teammate Points, same season | Objective intra-team performance comparison |
| 15 | **Teammate Delta (Qualifying)** | Average `QualifyingPosition` (from `FactQualifying`) Driver − Average `QualifyingPosition` Teammate, same season | Isolates raw one-lap pace from race-day variance and grid penalties |
| 16 | **Undercut Success Rate** | Undercut Attempts That Gained Position ÷ Total Undercut Attempts | Strategy department execution quality |
| 17 | **Average Pit Window Variance** | StdDev of Pit Stop Lap by Circuit | How predictable/exploitable a circuit's pit windows are |
| 18 | **Points Trajectory (Rolling 5-Race)** | Rolling sum/average of points over last 5 races | Momentum indicator for in-season trend reporting |
| 19 | **Grid-to-Finish Correlation** | Correlation coefficient of grid vs. finish position, by circuit | Circuit "predictability" score for strategy planning |
| 20 | **Safety Car Impact Index** | Average position change in races with a Safety Car vs. without | Strategy risk/opportunity indicator per circuit |
| 21 | **Home Race Performance Delta** | Constructor's home-race average finish − season average finish | PR/marketing and morale-relevant metric |
| 22 | **Wet Race Performance Delta** | Driver's average finish in wet races − average finish in dry races | Identifies wet-weather specialists |
| 23 | **Rookie Season Index** | Rookie's points as % of experienced teammate's points, debut season | Talent evaluation benchmark |
| 24 | **Peak Performance Window Length** | Consecutive seasons a driver/constructor finished top-3 in championship | Sustained excellence indicator for legacy/valuation framing |
| 25 | **Competitive Spread Index** | (Slowest Constructor Avg Lap − Fastest Constructor Avg Lap) ÷ Fastest | Field parity indicator, season and circuit level |
| 26 | **Mechanical DNF Rate by Circuit** | Mechanical DNFs at Circuit ÷ Races at Circuit | Circuit-specific reliability risk profile |
| 27 | **Points Cost of DNF** | Average championship points lost per DNF (modeled against expected finish) | Quantifies reliability risk in points terms for leadership |
| 28 | **Multi-Stop Strategy Win Rate** | Wins with 2+ stops ÷ Races with 2+ stops, by circuit | Strategy decision support for compound choice |
| 29 | **Season Parity Index** | Distinct Race Winners ÷ Total Races, per season | League-wide competitiveness trend |
| 30 | **Development Trajectory Score** | Rolling 3-season change in average finishing position, constructor-level | Long-term investment/resourcing signal for Team Principal |

## Notes on KPI Design

- KPIs 1–12 are **outcome and pace** metrics — the baseline scorecard any stakeholder checks first.
- KPIs 13–20 are **operational/strategy execution** metrics — these are what differentiate this platform from a generic "F1 stats" dashboard, since they measure the *team's* decision quality, not just driver talent.
- KPIs 21–25 are **context-adjusted** metrics — they control for circumstance (home race, weather, rookie status) so comparisons are fair.
- KPIs 26–30 are **risk and trend** metrics aimed specifically at the Team Principal and Sporting Director audience, who care about trajectory and exposure more than single-race results.
