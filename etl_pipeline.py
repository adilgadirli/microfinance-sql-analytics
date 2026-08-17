import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL)

def extract_data(engine):
    """Extracts raw loan and payment datasets from PostgreSQL."""
    query_loans = "SELECT * FROM loans;"
    query_payments = "SELECT * FROM payments;"
    
    loans_df = pd.read_sql(query_loans, engine)
    payments_df = pd.read_sql(query_payments, engine)
    return loans_df, payments_df

def transform_data(loans_df, payments_df):
    """
    Transforms raw data by calculating max delay per loan 
    and assigning regulatory credit risk buckets.
    """
    # Group payments to find max delinquency days
    max_late = payments_df.groupby('loan_id')['days_late'].max().reset_index()
    
    # Merge with loans dataset
    merged = pd.merge(loans_df, max_late, on='loan_id', how='left')
    merged['days_late'] = merged['days_late'].fillna(0)
    
    # Categorize risk buckets
    def assign_risk_bucket(days):
        if days == 0:
            return '1. Current'
        elif days <= 30:
            return '2. PAR 1-30'
        elif days <= 90:
            return '3. PAR 31-90'
        else:
            return '4. NPL / PAR 90+'
            
    merged['risk_bucket'] = merged['days_late'].apply(assign_risk_bucket)
    return merged

def load_data(df, engine):
    """Loads transformed analytical data back to PostgreSQL as a Data Mart table."""
    df.to_sql('data_mart_risk', engine, if_exists='replace', index=False)
    print("ETL Pipeline executed successfully! Data loaded into 'data_mart_risk' table.")

if __name__ == "__main__":
    db_url = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(db_url)
    
    loans, payments = extract_data(engine)
    transformed_df = transform_data(loans, payments)
    load_data(transformed_df, engine)