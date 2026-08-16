-- 6. Data Mart Views Creation
CREATE OR REPLACE VIEW vw_risk_monitoring AS
WITH LoanMaxDelay AS (
    SELECT 
        l.loan_id,
        l.customer_id,
        l.loan_amount,
        l.term_months,
        l.interest_rate,
        l.status,
        l.disbursement_date,
        MAX(COALESCE(p.days_late, 0)) AS max_days_late
    FROM loans l
    LEFT JOIN payments p ON l.loan_id = p.loan_id
    GROUP BY l.loan_id, l.customer_id, l.loan_amount, l.term_months, l.interest_rate, l.status, l.disbursement_date
)
SELECT 
    loan_id,
    customer_id,
    loan_amount,
    term_months,
    interest_rate,
    status,
    disbursement_date,
    max_days_late,
    CASE 
        WHEN max_days_late = 0 THEN '1. Current'
        WHEN max_days_late <= 30 THEN '2. PAR 1-30'
        WHEN max_days_late <= 90 THEN '3. PAR 31-90'
        ELSE '4. NPL / PAR 90+'
    END AS risk_category
FROM LoanMaxDelay;

CREATE OR REPLACE VIEW vw_city_portfolio_performance AS
SELECT 
    c.city,
    COUNT(l.loan_id) AS total_loans_count,
    COUNT(CASE WHEN l.status = 'Active' THEN 1 END) AS active_loans_count,
    SUM(l.loan_amount) AS total_portfolio_value,
    ROUND(AVG(l.loan_amount), 2) AS avg_loan_size
FROM customers c
JOIN loans l ON c.customer_id = l.customer_id
GROUP BY c.city;