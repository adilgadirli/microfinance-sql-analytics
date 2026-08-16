-- 1. Database Cleanup
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS customers;

-- 2. Schema Creation
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    city VARCHAR(50),
    join_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE loans (
    loan_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id) ON DELETE CASCADE,
    loan_amount NUMERIC(12,2) CHECK (loan_amount > 0),
    term_months INT CHECK (term_months BETWEEN 6 AND 36),
    interest_rate NUMERIC(4,2),
    status VARCHAR(20) DEFAULT 'Active',
    disbursement_date DATE
);

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loans(loan_id) ON DELETE CASCADE,
    payment_date DATE,
    amount_paid NUMERIC(12,2) CHECK (amount_paid >= 0),
    days_late INT DEFAULT 0
);

-- 3. Synthetic Data Generation (2,000 CA Borrowers)
INSERT INTO customers (full_name, city, join_date)
SELECT 
    (ARRAY['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica', 'Thomas', 'Sarah', 'Charles', 'Karen'])[FLOOR(RANDOM() * 20 + 1)] 
    || ' ' || 
    (ARRAY['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee'])[FLOOR(RANDOM() * 20 + 1)] AS full_name,
    (ARRAY['Los Angeles', 'San Diego', 'San Jose', 'San Francisco', 'Fresno', 'Sacramento', 'Long Beach', 'Oakland', 'Bakersfield', 'Anaheim'])[FLOOR(RANDOM() * 10 + 1)] AS city,
    CURRENT_DATE - (FLOOR(RANDOM() * 730)::INT) AS join_date
FROM generate_series(1, 2000) AS seq;

-- 4. Synthetic Data Generation (5,000 Loans with Real Portfolio Distribution)
INSERT INTO loans (customer_id, loan_amount, term_months, interest_rate, status, disbursement_date)
SELECT 
    FLOOR(RANDOM() * 2000 + 1)::INT AS customer_id,
    ROUND((RANDOM() * 14000 + 1000)::NUMERIC, 2) AS loan_amount,
    (ARRAY[6, 12, 18, 24, 30, 36])[FLOOR(RANDOM() * 6 + 1)] AS term_months,
    ROUND((RANDOM() * 10 + 10)::NUMERIC, 2) AS interest_rate,
    CASE 
        WHEN RANDOM() < 0.78 THEN 'Active'
        WHEN RANDOM() < 0.95 THEN 'Closed'
        ELSE 'Defaulted'
    END AS status,
    CURRENT_DATE - (FLOOR(RANDOM() * 365)::INT) AS disbursement_date
FROM generate_series(1, 5000) AS seq;

-- 5. Synthetic Data Generation (15,000 Payments Aligned with Risk Logic)
INSERT INTO payments (loan_id, payment_date, amount_paid, days_late)
SELECT 
    l.loan_id,
    l.disbursement_date + (seq * 30) AS payment_date,
    ROUND((l.loan_amount / l.term_months)::NUMERIC, 2) AS amount_paid,
    CASE 
        WHEN l.status = 'Closed' THEN 0
        WHEN l.status = 'Defaulted' THEN FLOOR(RANDOM() * 60 + 91)::INT
        ELSE 
            CASE 
                WHEN RANDOM() < 0.88 THEN 0
                WHEN RANDOM() < 0.95 THEN FLOOR(RANDOM() * 29 + 1)::INT
                ELSE FLOOR(RANDOM() * 60 + 31)::INT
            END
    END AS days_late
FROM loans l
CROSS JOIN generate_series(1, 3) AS seq;