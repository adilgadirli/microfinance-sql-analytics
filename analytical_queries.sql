-- ============================================================
-- Microfinance Loan Portfolio Analytics
-- Author: Adil Gadirli
-- Purpose: Analytical queries for credit risk, customer behavior,
--          and city-level market analysis.
-- ============================================================

-- Query 1: Customer Portfolio Exposure & Non-Borrowers
-- Business Question: What is the total loan exposure per customer, 
-- and which registered clients have no borrowing history?
SELECT 
    c.customer_id,
    c.full_name,
    c.city,
    COUNT(l.loan_id) AS total_loans,
    COALESCE(SUM(l.loan_amount), 0) AS total_disbursed_amount
FROM customers c
LEFT JOIN loans l ON c.customer_id = l.customer_id
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY total_disbursed_amount DESC
LIMIT 10;


-- Query 2: Market Level Aggregation & High-Ticket Filtering
-- Business Question: Which California municipal markets generate 
-- the highest average loan ticket sizes above $4,000 threshold?
SELECT 
    c.city,
    COUNT(l.loan_id) AS total_loans,
    ROUND(AVG(l.loan_amount), 2) AS avg_loan_amount,
    SUM(l.loan_amount) AS total_portfolio
FROM customers c
JOIN loans l ON c.customer_id = l.customer_id
GROUP BY c.city
HAVING AVG(l.loan_amount) > 4000
ORDER BY total_portfolio DESC;


-- Query 3: Sequential Borrowing Behavior & Delta Tracking
-- Business Question: Are repeat borrowers expanding their credit intake 
-- over sequential loan originations?
SELECT 
    customer_id,
    loan_id,
    loan_amount,
    term_months,
    disbursement_date,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY disbursement_date) AS loan_sequence,
    LAG(loan_amount, 1) OVER(PARTITION BY customer_id ORDER BY disbursement_date) AS previous_loan_amount,
    loan_amount - LAG(loan_amount, 1) OVER(PARTITION BY customer_id ORDER BY disbursement_date) AS loan_amount_difference
FROM loans
LIMIT 20;


-- Query 4: Portfolio Delinquency Risk & PAR30+ Default Analysis
-- Business Question: What is the PAR30+ delinquency rate across 
-- active, closed, and defaulted loan portfolios?
WITH RiskAnalysis AS (
    SELECT 
        l.loan_id,
        l.status,
        l.loan_amount,
        MAX(COALESCE(p.days_late, 0)) AS max_days_late
    FROM loans l
    LEFT JOIN payments p ON l.loan_id = p.loan_id
    GROUP BY l.loan_id, l.status, l.loan_amount
)
SELECT 
    status,
    COUNT(loan_id) AS total_loans,
    SUM(loan_amount) AS total_exposure,
    ROUND(
        SUM(CASE WHEN max_days_late > 30 THEN loan_amount ELSE 0 END) * 100.0 / NULLIF(SUM(loan_amount), 0), 
        2
    ) AS default_rate_pct
FROM RiskAnalysis
GROUP BY status;