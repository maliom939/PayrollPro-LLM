few_shots = [
    {
        'Question': "Which employee took the most leaves?",
        'SQLQuery': "SELECT e.full_name FROM takes_leave tl JOIN employee e ON e.emp_ID = tl.emp_ID GROUP BY tl.emp_ID ORDER BY SUM(DATEDIFF(tl.end_date,tl.start_date)+1) DESC LIMIT 1",
        'SQLResult': "Result of the SQL query",
        'Answer': 'Laura Gentry'
    },
    {
        'Question': "Which position had its employees working for most days on average?",
        'SQLQuery': "SELECT p.name FROM Employee e JOIN positions p ON e.pos_ID = p.pos_ID JOIN attendance a ON e.emp_ID = a.emp_ID GROUP BY p.name ORDER BY AVG(a.days_worked) DESC LIMIT 1",        
        'SQLResult': "Result of the SQL query",
        'Answer': 'Research Engineer'
    },
    {
        'Question': "Which employee took the most leaves?",
        'SQLQuery': "SELECT a.month_, a.year_ FROM takes_leave tl JOIN attendance a ON tl.emp_ID = a.emp_ID  AND CAST(DATE_FORMAT(tl.start_date ,'%Y-%m-01') as DATE) <= str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', '01'), '%Y-%m-%d') AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', '01'), '%Y-%m-%d') <= CAST(DATE_FORMAT(tl.end_date ,'%Y-%m-01') as DATE) GROUP BY a.year_, a.month_ ORDER BY COUNT(*) DESC LIMIT 1",
        'SQLResult': "Result of the SQL query",
        'Answer': '(5, 2023)'
    }
]