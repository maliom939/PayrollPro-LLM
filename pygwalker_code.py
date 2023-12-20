import streamlit as  st
from pygwalker.api.streamlit import StreamlitRenderer
import pandas as pd
import pygwalker as pyg
import mysql.connector

def load_data(db_connector, df_type):
    if df_type == 'Company Statistics':
        query = "SELECT e.emp_ID, e.full_name, e.gender, e.age, e.join_date, e.has_child, e.bank_name, e.acc_type, e.r_plan, e.retirement_amount, d.name AS 'department', d.dept_pay, p.name AS 'position', p.pos_pay, g.title, g.grade_pay FROM employee e JOIN department d ON e.dept_ID = d.dept_ID JOIN positions p on e.pos_ID = p.pos_ID JOIN grade g ON g.grade_ID = e.grade_ID"

        df = pd.read_sql(query, db_connector)

    elif df_type == 'Employee Attedance and Pay':
        query = "SELECT a.emp_ID, e.full_name, a.month_ AS 'month', a.year_ AS 'year', a.days_worked, a.hrs_worked AS 'hours_worked', p.gross_pay, p.net_pay FROM attendance a JOIN Employee e ON e.emp_ID = a.emp_ID JOIN payroll_ p ON a.emp_ID = p.emp_ID AND a.month_ = p.month_ AND a.year_ = p.year_"

        df = pd.read_sql(query, db_connector)
        df['month_year'] = pd.to_datetime(df['year'].astype(str) + '/' + df['month'].astype(str) + '/01')

    return df


# Display PyGWalker
def load_config(df_type):
    if df_type == 'Company Statistics':
        with open("company_statistics.json", 'r') as config_file:
            config_str = config_file.read()

    elif df_type == 'Employee Attedance and Pay':
        with open("attendance_pay_graph.json", 'r') as config_file:
            config_str = config_file.read()
    return config_str



def display_graph(df_type) -> "StreamlitRenderer":
    db_connector = mysql.connector.connect(
        host="localhost",
        user="root",
        password="password",
        database="payroll_db_tmp"
    )
    df = load_data(db_connector, df_type)
    # config = load_config(df_type)

    if df_type == 'Company Statistics':
        renderer = StreamlitRenderer(df, spec="./company_statistics.json", debug=False)
    elif df_type == 'Employee Attedance and Pay':
        renderer = StreamlitRenderer(df, spec="./attendance_pay_graph.json", debug=False)

    return renderer
    # pyg.walk(df, env='Streamlit', dark='dark', spec=config)