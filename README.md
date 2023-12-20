# PayrollPro-LLM
An application for organizational payroll management, employing a Large Language Model (LLM) to interact with the payroll database and featuring an interactive dashboard for uncovering additional insights.

The Database was created using MySQL and is made up of of 16 tables. It consists of 5 functions, 4 stored procedures and 6 Triggers.

![Alt text](/Final_ERD.jpeg?raw=true "Title")

The application, built with Streamlit, utilized Langchain to query the database through the Google Palm Large Language Model (LLM) and fine-tuned the model using the Few-Shot Learning technique.
![Alt text](/project_images/qna.jpg?raw=true "Title")

PygWalker was employed to create an interactive dashboard within Streamlit. The "Company Statistics" drop-down option is utilized to showcase a dashboard containing organizational insights such as employee age and gender, as well as departmental, positional, and grade distributions.

![Alt text](/project_images/grade_and_position.jpg?raw=true "Title")

The "Employee Attendance and Pay" drop-down option is utilized to present a dashboard featuring payroll and attendance related information for an employee. Selection of the specific employee is facilitated through the "Filters" box within the dashboard.

**The salary is higher in December due to the awarding of bonuses during this month.**
![Alt text](/project_images/employee_salary.jpg?raw=true "Title")
