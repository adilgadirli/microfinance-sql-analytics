# Microfinance Loan Portfolio Analytics (PostgreSQL)

## Executive Summary
This repository contains an end-to-end credit risk and loan portfolio data analytics project for a microfinance institution operating across California (CA) municipal markets. The dataset simulates realistic portfolio delinquency distribution, repeat borrower behavior, and credit exposure metrics.

---

## Architecture Flow

    +----------------------------+      +---------------------+      +-----------------------+
    | Synthetic Data Generator   | ---> | PostgreSQL Database | ---> | SQL Analytical Layer  |
    +----------------------------+      +---------------------+      +-----------------------+
                                                                                 |
    [Power BI Dashboard] <---------- [Data Mart / Views] <-----------------------+

---

## Database Schema
The database consists of three relational tables enforced via PRIMARY KEY, FOREIGN KEY, and data integrity constraints:
- **customers**: Stores demographic information and registration dates for 2,000 California borrowers.
- **loans**: Tracks 5,000 credit accounts with variable tenures (6-36 months), interest rates, and loan statuses (Active, Closed, Defaulted).
- **payments**: Contains ~15,000 transaction records detailing installment amounts and delinquency days (days_late).

---

## Key Analytical Queries & Business Logic

### 1. Customer Exposure & Non-Borrower Identification
- **Business Question:** What is the total loan exposure per customer, and which registered clients have no active borrowing history?
- **Technical Highlights:** Uses LEFT JOIN and COALESCE(SUM(), 0) to quantify total disbursed amounts while preventing NULL representation for non-borrowing clients.

### 2. Geographic Market Aggregation
- **Business Question:** Which California municipal markets generate the highest average ticket sizes above a $4,000 threshold?
- **Technical Highlights:** Implements GROUP BY c.city combined with HAVING AVG(l.loan_amount) > 4000 to isolate high-value lending hubs.

![City Portfolio Performance](images/query2_city_performance.png)

### 3. Sequential Borrowing & Delta Analysis
- **Business Question:** Are repeat borrowers expanding their credit intake over sequential loan originations?
- **Technical Highlights:** Utilizes window functions (ROW_NUMBER() and LAG()) partitioned by customer_id to compute chronological loan order and period-over-period borrowing deltas.

### 4. Portfolio Delinquency Risk & PAR30+ Rate
- **Business Question:** What is the PAR30+ delinquency rate across active, closed, and defaulted loan portfolios?
- **Technical Highlights:** Constructs a CTE (RiskAnalysis) aggregating maximum delinquency days (MAX(days_late)) per account. Applies conditional aggregation (CASE WHEN max_days_late > 30 THEN loan_amount ELSE 0 END) and zero-division protection via NULLIF().

![PAR30+ Risk Analysis](images/query1_risk_analysis.png)

---

## Delinquency & PAR30+ Methodology
- **Delinquency Measurement:** Delinquency (days_late) is evaluated dynamically at the payment level rather than relying on static loan status labels.
- **PAR30+ Definition:** Portfolio at Risk > 30 Days represents the percentage of outstanding loan principal on accounts overdue by more than 30 days.
- **Data Integrity Alignment:** Closed accounts maintain a strict 0% risk baseline, while Defaulted accounts strictly reflect severe delinquency (>90 days late).

## Python ETL Pipeline & Data Mart Layer
The project features an automated Python ETL script (`etl_pipeline.py`) powered by `pandas` and `sqlalchemy` to transform raw operational tables into a reporting layer:
- **Extract:** Ingests relational tables (`loans` and `payments`) from the PostgreSQL database (`microfinance_analytics`).
- **Transform:** Aggregates peak delinquency days (`days_late`) per account and assigns risk classifications (`1. Current`, `2. PAR 1-30`, `3. PAR 31-90`, `4. NPL / PAR 90+`).
- **Load:** Dynamically writes the structured analytical output into a new database table (`data_mart_risk`) for Power BI reporting.