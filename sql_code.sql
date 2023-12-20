CREATE DATABASE IF NOT EXISTS payroll_db;
USE payroll_db;

DROP TABLE IF EXISTS Bank_Account;
CREATE TABLE Bank_Account(
   bank_name VARCHAR(255)
  ,acc_type  VARCHAR(255)
  ,PRIMARY KEY(bank_name,acc_type)
);

DROP TABLE IF EXISTS Bonus_and_Benefits;
CREATE TABLE Bonus_and_Benefits(
   b_type VARCHAR(255) NOT NULL PRIMARY KEY
  ,amount INT DEFAULT 0 NOT NULL
);

DROP TABLE IF EXISTS Department;
CREATE TABLE Department(
   dept_ID  VARCHAR(255) NOT NULL PRIMARY KEY
  ,name     VARCHAR(255) NOT NULL
  ,dept_pay DECIMAL(10, 2) NOT NULL DEFAULT 0
);

DROP TABLE IF EXISTS Grade;
CREATE TABLE Grade(
   grade_id  VARCHAR(255) NOT NULL PRIMARY KEY
  ,title     VARCHAR(255) NOT NULL
  ,grade_pay DECIMAL(10,2)  NOT NULL
);

DROP TABLE IF EXISTS Insurance;
CREATE TABLE Insurance(
   i_type  VARCHAR(255) NOT NULL PRIMARY KEY
  ,percent DECIMAL(10,2)  NOT NULL
);

DROP TABLE IF EXISTS Leaves;
CREATE TABLE Leaves(
   leave_ID         INT NOT NULL PRIMARY KEY
  ,name             VARCHAR(255) NOT NULL
  ,deduction_amount DECIMAL(10,2)  NOT NULL
  ,days_allowance   INT  NOT NULL
);

DROP TABLE IF EXISTS Positions;
CREATE TABLE Positions(
   pos_ID  VARCHAR(255) NOT NULL PRIMARY KEY
  ,name    VARCHAR(255) NOT NULL
  ,pos_pay DECIMAL(10,2)  NOT NULL
);

DROP TABLE IF EXISTS Retirement;
CREATE TABLE Retirement(
   r_plan  VARCHAR(255) PRIMARY KEY
  ,percent INT  NOT NULL
  ,pre_tax BOOL NOT NULL
);

DROP TABLE IF EXISTS Tax;
CREATE TABLE Tax(
   name    VARCHAR(255) NOT NULL PRIMARY KEY
  ,percent DECIMAL(10,2) NOT NULL
  ,min_pay DECIMAL(10,2)
  ,max_pay DECIMAL(10,2)
);

DROP TABLE IF EXISTS Employee;
CREATE TABLE Employee(
   emp_ID      VARCHAR(255) PRIMARY KEY
  ,full_name   VARCHAR(255) NOT NULL
  ,gender      VARCHAR(255) NOT NULL
  ,age         INT  NOT NULL
  ,email       VARCHAR(255) NOT NULL
  ,join_date   DATE  NOT NULL
  ,contact_num VARCHAR(10) NOT NULL
  ,has_child   BOOLEAN  NOT NULL
  ,account_num VARCHAR(255) NOT NULL
  ,bank_name   VARCHAR(255) NOT NULL
  ,acc_type    VARCHAR(255) NOT NULL
  ,dept_ID     VARCHAR(255) NOT NULL
  ,pos_ID      VARCHAR(255) NOT NULL
  ,grade_ID    VARCHAR(255) NOT NULL
  ,r_plan      VARCHAR(255) NOT NULL
  ,amount      DECIMAL(10,2)  NOT NULL DEFAULT 0
  ,FOREIGN KEY (bank_name, acc_type) REFERENCES Bank_Account(bank_name, acc_type)
  ,FOREIGN KEY (dept_ID) REFERENCES Department(dept_ID)
  ,FOREIGN KEY (pos_ID) REFERENCES Positions(pos_ID)
  ,FOREIGN KEY (grade_ID) REFERENCES Grade(grade_ID)
  ,FOREIGN KEY (r_plan) REFERENCES Retirement(r_plan)
);

DROP TABLE IF EXISTS Attendance;
CREATE TABLE Attendance(
   emp_ID      VARCHAR(255) 
  ,month_      INT CHECK (month_<13 and month_>0)
  ,year_       YEAR 
  ,days_worked INTEGER  NOT NULL
  ,hrs_worked  INTEGER  NOT NULL
  ,PRIMARY KEY (emp_ID, month_, year_)
  ,FOREIGN KEY (emp_ID) REFERENCES Employee(emp_ID)
  ,CHECK(hrs_worked <= days_worked*24)
);

DROP TABLE IF EXISTS Get_Bonus;
CREATE TABLE Get_Bonus(
   emp_ID VARCHAR(255)
  ,b_type VARCHAR(255)
  ,PRIMARY KEY(emp_ID,b_type)
  ,FOREIGN KEY (emp_ID) REFERENCES Employee(emp_ID)
  ,FOREIGN KEY (b_type) REFERENCES Bonus_and_Benefits(b_type)
);

DROP TABLE IF EXISTS Insures;
CREATE TABLE Insures(
   emp_ID VARCHAR(255)
  ,i_type VARCHAR(255)
  ,amount DECIMAL(10,2)  DEFAULT 0
  ,PRIMARY KEY (emp_ID,i_type)
  ,FOREIGN KEY (emp_ID) REFERENCES Employee(emp_ID)
  ,FOREIGN KEY (i_type) REFERENCES Insurance(i_type)
);

DROP TABLE IF EXISTS Takes_Leave;
CREATE TABLE Takes_Leave(
   emp_ID     VARCHAR(255) NOT NULL
  ,leave_ID   INT  NOT NULL
  ,start_date DATE  NOT NULL
  ,end_date   DATE  NOT NULL
  ,PRIMARY KEY (emp_ID, start_date)
  ,FOREIGN KEY (emp_ID) REFERENCES Employee(emp_ID)
  ,FOREIGN KEY (leave_ID) REFERENCES leaves(leave_ID)
  ,CHECK(end_date >= start_date)
);
    
DROP TABLE IF EXISTS Payroll_;
CREATE TABLE Payroll_(
   emp_ID VARCHAR(255)
  ,month_ INT CHECK (month_<13 and month_>0)
  ,year_  YEAR 
  ,gross_pay DECIMAL(10,2)
  ,net_pay DECIMAL(10,2)
  ,PRIMARY KEY (emp_ID,month_, year_)
  ,FOREIGN KEY (emp_ID) REFERENCES Employee(emp_ID)
);

DROP TABLE IF EXISTS taxes;
CREATE TABLE taxes(
	emp_ID VARCHAR(255)
    ,month_ INT CHECK (month_<13 and month_>0)
    ,year_ YEAR
    ,name VARCHAR(255)
    ,tax_amount DECIMAL(10,2) DEFAULT 0
    ,PRIMARY KEY(emp_ID, month_, year_, name)
    ,FOREIGN KEY(emp_ID,month_,year_) REFERENCES payroll_(emp_ID,month_,year_)
    ,FOREIGN KEY(name) REFERENCES Tax(name)
);

CREATE OR REPLACE VIEW employee_pay AS
SELECT e.emp_ID, e.full_name, a.month_, a.year_, a.days_worked, a.hrs_worked, p.gross_pay, p.net_pay
FROM Employee e
JOIN Attendance a ON a.emp_ID = e.emp_ID
JOIN Payroll_ p ON p.emp_ID = e.emp_ID AND a.month_ = p.month_ AND a.year_ = p.year_;

CREATE OR REPLACE VIEW employee_info AS
SELECT e.emp_ID AS "emp_ID", e.full_name, e.gender, e.age, e.join_date, d.name AS "Department", p.name AS "Position", g.title AS "Grade"
FROM Employee e 
JOIN Department d ON e.dept_ID = d.dept_ID
JOIN Positions p ON e.pos_ID = p.pos_ID
JOIN Grade g ON e.grade_ID = g.grade_ID
ORDER BY e.emp_ID;

-- Stored Procedures, Functions, Triggers -------------------------------------------------------------------

DROP FUNCTION IF EXISTS get_leave_deduction;
DELIMITER $$
CREATE FUNCTION get_leave_deduction(
	emp_ID VARCHAR(255),
    month_ INT,
    year_ YEAR
	
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE leave_deduction DECIMAL(10,2);
-- 	DECLARE last_date DATE;
    DECLARE personal_leave_deduc INT;
-- 	SET last_date = LAST_DAY(DATE(CONCAT_WS('-', year_, month_, 1)));
	SET leave_deduction = 0;
    SELECT deduction_amount INTO personal_leave_deduc FROM leaves WHERE leave_ID = 500;
    
    -- Recursive CTE to get months and years between the start and end date of leave.
    WITH RECURSIVE months_in_leave as (
	  select tl.emp_ID, tl.leave_ID, tl.start_date, tl.end_date, CAST(DATE_FORMAT(tl.start_date ,'%Y-%m-01') as DATE) AS "leave_month"
	  from takes_leave as tl
      WHERE tl.emp_ID = emp_ID and year(tl.start_date)=year_
	  union all
	  select ml.emp_ID, ml.leave_ID, ml.start_date+ interval 1 month, ml.end_date, CAST(DATE_FORMAT(ml.start_date+ interval 1 month ,'%Y-%m-01') as DATE)  AS "leave_month"
	  from months_in_leave as ml 
	  where last_day(ml.start_date) < ml.end_date
	),
    
    -- CTE to get number of leaves taken in the month, year between start and end date of leave.
    leave_days AS (
    SELECT ml.emp_ID, ml.leave_ID, ml.leave_month
    , tl.start_date, tl.end_date,
    CASE 
    WHEN CAST(DATE_FORMAT(tl.start_date ,'%Y-%m-01') as DATE) = CAST(DATE_FORMAT(tl.end_date ,'%Y-%m-01') as DATE) THEN datediff(tl.end_date, tl.start_date)+1
    WHEN ml.leave_month = CAST(DATE_FORMAT(tl.start_date ,'%Y-%m-01') as DATE) THEN datediff(LAST_DAY(tl.start_date),tl.start_date)+1
    WHEN ml.leave_month = CAST(DATE_FORMAT(tl.end_date ,'%Y-%m-01') as DATE) THEN datediff(tl.end_date, CAST(DATE_FORMAT(tl.end_date ,'%Y-%m-01') as DATE))+1 -- DATE_SUB(tl., INTERVAL DAY("2017-06-15")- 1 DAY))+1
    ELSE DAY(LAST_DAY(ml.leave_month))
    END AS "leaves_taken"
	FROM months_in_leave ml
    JOIN takes_leave tl ON ml.emp_ID=tl.emp_ID AND ml.leave_ID=tl.leave_ID AND 
		CAST(DATE_FORMAT(tl.start_date ,'%Y-%m-01') as DATE) <= ml.leave_month AND ml.leave_month <= CAST(DATE_FORMAT(tl.end_date ,'%Y-%m-01') as DATE)
    ORDER BY 1,2,3
    ),
    
    -- Find sum of leaves taken each month for each leave type and employee
    sum_leave_days AS (
		SELECT emp_ID, leave_ID, leave_month, SUM(leaves_taken) AS "month_leaves"
		FROM leave_days
        GROUP BY emp_ID, leave_ID, leave_month
    ),
    
    -- Find cumulative sum of the sum of leaves taken over a month for each employee and leave type
    cum_sum_leave_days AS (
	SELECT *, SUM(month_leaves) OVER(PARTITION BY emp_ID, leave_ID ORDER BY leave_month) AS "cumulative_sum"
    FROM sum_leave_days
    ),
    
    -- CTE to get the previous cumulative sum for 
    lag_cum_sum_leave_days AS (
    SELECT *, LAG(cumulative_sum,1,0) OVER(PARTITION BY emp_ID, leave_ID ORDER BY leave_month) AS "prev_cum_sum"
    FROM cum_sum_leave_days
    )
	
    -- CTE to assign penalty if number of leaves taken are more than the allowance
	,leave_penalty AS(
    SELECT lcs.* , l.days_allowance, l.deduction_amount,

    CASE
		WHEN lcs.cumulative_sum > l.days_allowance THEN
		CASE
			WHEN lcs.prev_cum_sum>=l.days_allowance THEN month_leaves*personal_leave_deduc
            ELSE (l.days_allowance-lcs.prev_cum_sum)*l.deduction_amount + (lcs.cumulative_sum-l.days_allowance)*personal_leave_deduc
		END
		ELSE month_leaves*l.deduction_amount
    END AS 'total_deduc'
    FROM lag_cum_sum_leave_days lcs
    JOIN leaves l ON lcs.leave_ID = l.leave_ID
    )
    
    -- Total deduction per month
	,sum_leave_penalty AS (
		SELECT emp_ID, leave_month, SUM(total_deduc) AS "Monthly_deduc"
		FROM leave_penalty
		GROUP BY emp_ID, leave_month
		ORDER BY emp_ID, leave_month
    )

    -- Return leave deduction for that month else return 0
	SELECT COALESCE((
				SELECT monthly_deduc
				FROM sum_leave_penalty
				WHERE leave_month = str_to_date(CONCAT(CAST(year_ AS CHAR(10)), '-', CAST(month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d')
            ),0) INTO leave_deduction

	;
    RETURN leave_deduction;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS get_gross_pay;
DELIMITER $$
-- Gross pay = sum of hourly pay of department, position and grade * number of hours worked in that month - leave deduction
CREATE PROCEDURE get_gross_pay(
	IN emp_ID VARCHAR(255)
    ,IN month_ INT
    ,IN year_ YEAR
    ,IN hrs_worked INT
    ,OUT res DECIMAL(10,2)
)
BEGIN
DECLARE leave_deduction DECIMAL(10,2);
SET leave_deduction = 0;

SELECT (d.dept_pay+p.pos_pay+g.grade_pay)*hrs_worked INTO res
FROM employee e
JOIN department d ON e.dept_ID = d.dept_ID
JOIN positions p ON e.pos_ID = p.pos_ID
JOIN grade g ON e.grade_ID = g.grade_id
WHERE e.emp_ID = emp_ID;

-- CALL get_leave_deduction(emp_ID, month_, year_, leave_deduction);
SET leave_deduction = get_leave_deduction(emp_ID, month_, year_);
SET res = res - IFNULL(leave_deduction,0);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS get_insurance_deduction;
DELIMITER $$
-- Insurance deduction is the sum of percentage for insurance deduction * gross pay
CREATE FUNCTION get_insurance_deduction(
	emp_ID VARCHAR(255),
    gross_pay DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
DECLARE res DECIMAL(10,2);
SET res = 0;

SELECT SUM(insu.percent)/100*gross_pay INTO res
FROM insures insr JOIN insurance insu ON insr.i_type = insu.i_type
WHERE insr.emp_ID = emp_ID
GROUP BY insr.emp_ID;

RETURN res;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS total_bonus_received;
DELIMITER $$
-- Total bonus is the sum of bonuses received depending upon the month, and joining date. Bonuses apart from joining bonus are given each december.
CREATE FUNCTION total_bonus_received (
    ID VARCHAR(255)
--     ,date_ DATE
    ,month_ INT
    ,year_ YEAR
    )
RETURNS INT 
DETERMINISTIC
BEGIN
    DECLARE bonus INT DEFAULT 0;
    DECLARE tmp_var INT;
    SET tmp_var = 0;
    SET bonus = 0;
    
	-- IF  MONTH(date_) = 12 THEN
    IF month_ = 12 THEN
		SELECT SUM(b.amount) 
		INTO bonus
		FROM bonus_and_benefits as b 
		WHERE b.b_type NOT IN ('Child Care assistance', 'Signing Bonus');

		IF (SELECT has_child FROM employee as e WHERE emp_ID = ID) = TRUE THEN
			SELECT b.amount
			INTO tmp_var
			FROM bonus_and_benefits as b 
			WHERE b.b_type = "Child Care assistance";
		END IF;
	
    SET bonus = bonus + tmp_var;
    SET tmp_var= 0;
    
    IF MONTH((SELECT join_date FROM employee WHERE emp_ID = ID)) = month_ -- MONTH(date_) 
		AND YEAR((SELECT join_date FROM employee WHERE emp_ID = ID)) = year_ THEN -- YEAR(date_) THEN
		SELECT b.amount 
		INTO tmp_var
		FROM bonus_and_benefits as b 
		WHERE b.b_type = 'Signing Bonus'; 
	END IF;
    
    SET bonus = bonus + tmp_var;
    
   END IF;
RETURN bonus;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS get_retirement_deduction;
DELIMITER $$
-- Retirement deduction gives the monthly deduction that is taken from gross pay for retirement savings. Its calculated based on the type of deduction.
-- If retirement deduction is pre tax, then its the product of gross pay and percent. Else its the product of (gross_pay-taxes) and percent.
CREATE FUNCTION get_retirement_deduction(
	emp_ID VARCHAR(255),
    gross_pay DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
DECLARE res DECIMAL(10,2);
SET res = 0;

SELECT r.percent/100*gross_pay INTO res
FROM retirement as r
JOIN employee as e ON r.r_plan = e.r_plan
WHERE e.emp_ID = emp_ID;

RETURN res;
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS get_tax_deduction;
DELIMITER $$
-- Tax deduction is calculated based on each month's gross pay thus the tax slabs are not fixed per employee.
CREATE FUNCTION get_tax_deduction(
	emp_ID VARCHAR(255),
    month_ INT,
    year_ YEAR,
    gross_pay DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
DECLARE tax_deduction DECIMAL(10,2);
SET tax_deduction = 0;

SELECT SUM(percent)/100 * gross_pay INTO tax_deduction
FROM tax
WHERE (min_pay<=gross_pay AND (gross_pay<max_pay OR isnull(max_pay))) OR isnull(min_pay);

RETURN tax_deduction;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS get_net_pay;
DELIMITER $$
-- Procedure to calculate net pay from gross pay, insurance deduction, bonuses, retirement deduction and taxes.
CREATE PROCEDURE get_net_pay(
	IN emp_ID VARCHAR(255)
    ,IN month_ INT
    ,IN year_ YEAR
    ,IN gross_pay DECIMAL(10,2)
    ,OUT net_pay DECIMAL(10,2)
)
BEGIN
DECLARE insures_deduction DECIMAL(10,2);
DECLARE bonus_deduction DECIMAL(10,2);
DECLARE retirement_deduction DECIMAL(10,2);
DECLARE tax_deduction DECIMAL(10,2);
DECLARE pre_tax_var BOOL;
SET insures_deduction = 0;
SET bonus_deduction = 0;
SET retirement_deduction = 0;
SET tax_deduction = 0;

SET net_pay = 0;

SET tax_deduction = get_tax_deduction(emp_ID, month_, year_, gross_pay);

SELECT r.pre_tax INTO pre_tax_var FROM Employee e JOIN retirement r ON e.r_plan = r.r_plan WHERE e.emp_ID = emp_ID;
IF pre_tax_var = TRUE THEN
	SET retirement_deduction = get_retirement_deduction(emp_ID, gross_pay);
ELSE
	SET retirement_deduction = get_retirement_deduction(emp_ID, gross_pay-tax_deduction); 
END IF;

SET insures_deduction =  get_insurance_deduction(emp_ID, gross_pay);
SET bonus_deduction = total_bonus_received(emp_ID, month_, year_);-- DATE(CONCAT_WS('-', year_, month_, 1)));

SET net_pay = gross_pay - insures_deduction + bonus_deduction - retirement_deduction - tax_deduction ;

END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS insert_payroll_from_attendance;
DELIMITER $$
-- Procedure to insert calculated payroll and taxes in their tables.
CREATE PROCEDURE insert_payroll_from_attendance(
	IN emp_ID VARCHAR(255)
    ,IN month_ INT
    ,IN year_ YEAR
	,IN hrs_worked INT
    ,OUT new_gross_pay DECIMAL(10,2)
    ,OUT new_net_pay DECIMAL(10,2)
    ,OUT retirement_deduction DECIMAL(10,2)
)
BEGIN
	DECLARE tax_deduction DECIMAL(10,2);
	DECLARE pre_tax_var BOOL;
    
    SET new_gross_pay = 0;
    SET new_net_pay = 0;
    
    CALL get_gross_pay(emp_ID, month_, year_, hrs_worked, new_gross_pay);
	-- SET new_gross_pay = get_gross_pay_new(emp_ID, month_, year_, hrs_worked);
    CALL get_net_pay(emp_ID, month_, year_, new_gross_pay, new_net_pay);
	
    SET retirement_deduction=0;
    
    SET tax_deduction = get_tax_deduction(emp_ID, month_, year_, new_gross_pay);
	SELECT r.pre_tax INTO pre_tax_var FROM Employee e JOIN retirement r ON e.r_plan = r.r_plan WHERE e.emp_ID = emp_ID;
	IF pre_tax_var = TRUE THEN
		SET retirement_deduction = IFNULL(get_retirement_deduction(emp_ID, new_gross_pay),0);
	ELSE
		SET retirement_deduction = IFNULL(get_retirement_deduction(emp_ID, new_gross_pay-tax_deduction),0); 
	END IF;

    INSERT INTO Payroll_ VALUES(emp_ID, month_, year_, new_gross_pay, new_net_pay);
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS drop_payroll;
DELIMITER $$
-- Procedure to drop the payroll and taxes table for given employee, month, year and remove the amount contributed by empployee that month from insurance and retirement savings.
CREATE PROCEDURE drop_payroll(
	IN emp_ID VARCHAR(255)
    ,IN month_ INT
    ,IN year_ YEAR
)
BEGIN
DECLARE gross_pay_var DECIMAL(10,2);
DECLARE tax_sum DECIMAL(10,2);
DECLARE pre_tax_var BOOL;

SELECT gross_pay INTO gross_pay_var FROM payroll_ p WHERE p.emp_ID = emp_ID AND p.month_ = month_ AND p.year_ = year_;

SELECT SUM(tax_amount) INTO tax_sum FROM taxes t WHERE t.emp_ID = emp_ID AND t.month_ = month_ AND t.year_ = year_;

SELECT r.pre_tax INTO pre_tax_var FROM Employee e JOIN retirement r ON e.r_plan = r.r_plan WHERE e.emp_ID = emp_ID;
IF pre_tax_var = TRUE THEN
    UPDATE Employee e JOIN Retirement r ON e.r_plan = r.r_plan
    SET e.amount = e.amount - IFNULL((gross_pay_var * r.percent/100),0)
    WHERE e.emp_ID = emp_ID;
ELSE
    UPDATE Employee e JOIN Retirement r ON e.r_plan = r.r_plan
    SET e.amount = e.amount - IFNULL(((gross_pay_var-tax_sum) * r.percent/100),0)
    WHERE e.emp_ID = emp_ID;
END IF;

UPDATE Insures insr JOIN Insurance insu ON insr.i_type = insu.i_type
SET insr.amount = insr.amount - IFNULL((gross_pay_var * insu.percent/100),0)
WHERE insr.emp_ID = emp_ID;

DELETE FROM payroll_ p
WHERE p.emp_ID = emp_ID AND p.month_ = month_ AND p.year_ = year_;

END $$
DELIMITER ;

-- ---------------------------------- Triggers --------------------------------

DROP TRIGGER IF EXISTS insert_attendance_trigger;
DELIMITER $$
-- Trigger when attendance is recorded for an employee. It inserts the payroll, taxes for that employee for given month, year and increments the insurance and retirement savings by their respective deductions for each employee.
CREATE TRIGGER insert_attendance_trigger AFTER INSERT ON attendance
FOR EACH ROW
BEGIN
	DECLARE new_gross_pay DECIMAL(10,2);
    DECLARE new_net_pay DECIMAL(10,2);
    DECLARE retirement_deduction DECIMAL(10,2);
	CALL insert_payroll_from_attendance(new.emp_ID, new.month_, new.year_, new.hrs_worked, new_gross_pay, new_net_pay, retirement_deduction);
    
	UPDATE insures insr
	JOIN insurance insu ON insr.i_type = insu.i_type
	SET insr.amount = IFNULL(insr.amount,0) + IFNULL((new_gross_pay * insu.percent/100),0)
	WHERE insr.emp_ID = new.emp_ID;
    
	UPDATE employee e
	SET e.amount = IFNULL(e.amount,0) + IFNULL(retirement_deduction,0)
	WHERE e.emp_ID = new.emp_ID;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS b4_update_attendance_trigger;
DELIMITER $$
-- Trigger for before an update takes place in the attendance table. It deletes the payroll, taxes for the corresponding attendance and removes the amount contributed by empployee that month from insurance and retirement savings.
CREATE TRIGGER b4_update_attendance_trigger BEFORE UPDATE ON Attendance
FOR EACH ROW
BEGIN
	DECLARE old_gross_pay_var DECIMAL(10,2);
    DECLARE old_tax_sum_var DECIMAL(10,2);
    DECLARE old_pre_tax_var BOOL;
    
    SELECT IFNULL(gross_pay,0) INTO old_gross_pay_var FROM payroll_ p WHERE p.emp_ID = old.emp_ID AND p.month_ = old.month_ AND p.year_ = old.year_;

	SELECT IFNULL(SUM(tax_amount),0) INTO old_tax_sum_var FROM taxes t WHERE t.emp_ID = old.emp_ID AND t.month_ = old.month_ AND t.year_ = old.year_;

	SELECT r.pre_tax INTO old_pre_tax_var FROM Employee e JOIN retirement r ON e.r_plan = r.r_plan WHERE e.emp_ID = old.emp_ID;
	IF old_pre_tax_var = TRUE THEN
		UPDATE Employee e JOIN Retirement r ON e.r_plan = r.r_plan
		SET e.amount = IFNULL(e.amount,0) - IFNULL((old_gross_pay_var * r.percent/100),0)
		WHERE e.emp_ID = old.emp_ID;
	ELSE
		UPDATE Employee e JOIN Retirement r ON e.r_plan = r.r_plan
		SET e.amount = IFNULL(e.amount,0) - IFNULL(((old_gross_pay_var-old_tax_sum_var) * r.percent/100),0)
		WHERE e.emp_ID = old.emp_ID;
	END IF;

	UPDATE Insures insr JOIN Insurance insu ON insr.i_type = insu.i_type
	SET insr.amount = IFNULL(insr.amount,0) - IFNULL((old_gross_pay_var * insu.percent/100),0)
	WHERE insr.emp_ID = old.emp_ID;
    
    DELETE FROM payroll_ p
	WHERE p.emp_ID = old.emp_ID AND p.month_ = old.month_ AND p.year_ = old.year_;
    
	END $$
DELIMITER ;

DROP TRIGGER IF EXISTS af_update_attendance_trigger;
DELIMITER $$
-- Trigger that takes place after an attendance update. It inserts the new payroll, taxes and updates insures and retirement savings for respective employee.
CREATE TRIGGER af_update_attendance_trigger AFTER UPDATE ON Attendance
FOR EACH ROW
BEGIN
	DECLARE new_gross_pay DECIMAL(10,2);
    DECLARE new_net_pay DECIMAL(10,2);
    DECLARE retirement_deduction DECIMAL(10,2);
	CALL insert_payroll_from_attendance(new.emp_ID, new.month_, new.year_, new.hrs_worked, new_gross_pay, new_net_pay, retirement_deduction);
    
	UPDATE insures insr
	JOIN insurance insu ON insr.i_type = insu.i_type
	SET insr.amount = IFNULL(insr.amount,0) + IFNULL((new_gross_pay * insu.percent/100),0)
	WHERE insr.emp_ID = new.emp_ID;
    
	UPDATE employee e
	SET e.amount = IFNULL(e.amount,0) + IFNULL(retirement_deduction,0)
	WHERE e.emp_ID = new.emp_ID;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS delete_attendance_trigger;
DELIMITER $$
-- Trigger that handles the deletion of payroll, and modification of insurance and retirement savings.
CREATE TRIGGER delete_attendance_trigger BEFORE DELETE ON Attendance
FOR EACH ROW
BEGIN
	CALL drop_payroll(old.emp_ID, old.month_, old.year_);
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS insert_payroll_trigger;
DELIMITER $$
-- Trigger that calculates taxes for each payroll inserted.
CREATE TRIGGER insert_payroll_trigger AFTER INSERT ON Payroll_
FOR EACH ROW
BEGIN
	INSERT INTO Taxes
	SELECT NEW.emp_ID, NEW.month_, NEW.year_, name, percent/100 * NEW.gross_pay
	FROM Tax
	WHERE (min_pay<=NEW.gross_pay AND (NEW.gross_pay<max_pay OR isnull(max_pay))) OR isnull(min_pay);
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS delete_payroll_trigger;
DELIMITER $$
-- Trigger that deletes taxes for each payroll deleted.
CREATE TRIGGER delete_payroll_trigger BEFORE DELETE ON payroll_
FOR EACH ROW
BEGIN
	DELETE FROM Taxes t
	WHERE t.emp_ID = old.emp_ID AND t.month_ = old.month_ AND t.year_ = old.year_;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS insert_takes_leave_trigger;
DELIMITER $$
-- Trigger that handles the modification of attendance, payroll, insurance and retirement savings for each month in the leave inserted.
CREATE TRIGGER insert_takes_leave_trigger AFTER INSERT ON takes_leave
FOR EACH ROW
BEGIN
	UPDATE Attendance a
    SET a.emp_ID = new.emp_ID -- a.days_worked = a.days_worked 
    WHERE a.emp_ID = new.emp_ID
    -- AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d') >= CAST(DATE_FORMAT(new.start_date ,'%Y-%m-01') as DATE)
	-- BETWEEN new.start_date AND new.end_date
	AND CAST(DATE_FORMAT(new.start_date ,'%Y-%m-01') as DATE) <= str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d')
	AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d') <= CAST(DATE_FORMAT(new.end_date ,'%Y-%m-01') as DATE)
    ;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS af_update_takes_leave_trigger;
DELIMITER $$
-- Trigger that removes the previous leave and its effect on payroll, taxes, insurance and retirement savings. It then adds new leave and updates others accordingly.
CREATE TRIGGER af_update_takes_leave_trigger AFTER UPDATE ON takes_leave
FOR EACH ROW
BEGIN
	UPDATE Attendance a
    SET a.days_worked = a.days_worked
    WHERE a.emp_ID = old.emp_ID
	AND CAST(DATE_FORMAT(old.start_date ,'%Y-%m-01') as DATE) <= str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d')
	AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d') <= CAST(DATE_FORMAT(old.end_date ,'%Y-%m-01') as DATE)
    ;
	UPDATE Attendance a
    SET a.days_worked = a.days_worked
    WHERE a.emp_ID = new.emp_ID
	AND CAST(DATE_FORMAT(new.start_date ,'%Y-%m-01') as DATE) <= str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d')
	AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d') <= CAST(DATE_FORMAT(new.end_date ,'%Y-%m-01') as DATE)
    ;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS delete_takes_leave_trigger;
DELIMITER $$
-- Trigger that removes the previous leave and its effect on payroll, taxes, insurance and retirement savings.
CREATE TRIGGER delete_takes_leave_trigger AFTER DELETE ON takes_leave
FOR EACH ROW
BEGIN
	UPDATE Attendance a
    SET a.days_worked = a.days_worked
    WHERE a.emp_ID = old.emp_ID
	AND CAST(DATE_FORMAT(old.start_date ,'%Y-%m-01') as DATE) <= str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d')
	AND str_to_date(CONCAT(CAST(a.year_ AS CHAR(10)), '-', CAST(a.month_ AS CHAR(10)),'-', "01"), '%Y-%m-%d') <= CAST(DATE_FORMAT(old.end_date ,'%Y-%m-01') as DATE)
    ;
END $$
DELIMITER ;

-- Insertion ----------------------------------------------------------------------------------------------------

-- Bank Account ---------------------------------------------------
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Chase Bank','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Bank of America','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Santander','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Citi bank','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('U.S. Bank','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('PNC Bank','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Wells fargo','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Capital One','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Truist Financial','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Goldman Sachs','Savings');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Chase Bank','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Bank of America','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Santander','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Citi bank','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('U.S. Bank','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('PNC Bank','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Wells fargo','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Capital One','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Truist Financial','Checking');
INSERT INTO Bank_Account(bank_name,acc_type) VALUES ('Goldman Sachs','Checking');


-- Bonus And Benefits--------------------------------
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Christmas Bonus',500);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Thanksgiving Bonus',300);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Labour Day Bonus',300);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Commuter Benefit',1500);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Relocation Assistance',2000);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Lunch Coupon',7000);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Education',1000);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Gym coupon',200);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Child Care assistance',2000);
INSERT INTO Bonus_and_Benefits(b_type,amount) VALUES ('Signing Bonus',1000);

-- Department ---------------------------------------------------
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('H01','Human Resources',10.1);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('F08','Finance',11.15);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('IT02','Information Technology',13.51);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('M87','Marketing',11.64);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('O56','Operations',15.38);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('CS78','Customer Service',10.3);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('SL65','Sales',11.05);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('RD65','Research and Development',14.73);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('A51','Administration',10.4);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('LL01','Legal',14.26);
INSERT INTO Department(dept_ID,name,dept_pay) VALUES ('NA','NA',0);


-- Grade ---------------------------------------------------
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('IN','Intern',0);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('EL','Entry-level',5);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('JU','Junior',8);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('AS1','Associate 1',10);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('AS2','Associate 2',12);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('SE','Senior',16);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('LE','Lead',18);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('SP','Specialist',22);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('MA','Manager',24);
INSERT INTO Grade(grade_id,title,grade_pay) VALUES ('HL','High Level',25);

-- Insurance ---------------------------------------------------
INSERT INTO Insurance(i_type,percent) VALUES ('Health Insurance 1',0.75);
INSERT INTO Insurance(i_type,percent) VALUES ('Health Insurance 2',1);
INSERT INTO Insurance(i_type,percent) VALUES ('Health Insurance 3',2);
INSERT INTO Insurance(i_type,percent) VALUES ('Dental Insurance',1);
INSERT INTO Insurance(i_type,percent) VALUES ('Life Insurance',5);
INSERT INTO Insurance(i_type,percent) VALUES ('Disability Insurance',1);
INSERT INTO Insurance(i_type,percent) VALUES ('Accidental Death and Dismemberment (AD&D) Insurance',2);
INSERT INTO Insurance(i_type,percent) VALUES ('Long-Term Care Insurance',3);
INSERT INTO Insurance(i_type,percent) VALUES ('Critical Illness Insurance',0.5);
INSERT INTO Insurance(i_type,percent) VALUES ('Travel Insurance',1);

-- Leaves ---------------------------------------------------
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (100,'Maternity Leave',-160,30);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (200,'Paternity Leave',-160,15);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (300,'Annual Leave',0,20);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (400,'Sick Leave',0,7);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (500,'Personal Leave',45,0);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (600,'Bereavement Leave',-100,5);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (700,'Religious observance leave',0,2);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (800,'Study Leave',0,30);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (900,'Family Care Leave',0,7);
INSERT INTO Leaves(leave_ID,name,deduction_amount,days_allowance) VALUES (1000,'Adverse weather leave',-50,5);


-- Positions ---------------------------------------------------
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('HRA','HR Assistant',5);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('RC','Recruiter',8);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('HRB','HR Benefits Analyst',11);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('ACC','Accountant',9);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('FA','Financial Analyst',13);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('DS','Data Scientist',13);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('DA','Data Analyst',9);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('SWE','Software Engineer',9);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('TES','Hw/Sw Tester',7);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('MRA','Market Research Analyst',7);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('GD','Graphic Designer',9);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('BA','Business Analyst',13);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('OA','Operations Analyst',10);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('CS','Customer Support',6);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('SC','Sales Coordinator',9);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('SE','Sales Engineer',13);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('RE','Research Engineer',13);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('OFA','Office Administrator',10);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('AA','Administrative Assistant',7);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('LC','Legal Counsel',15);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('DI','Director',20);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('VI','Vice President',25);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('EE','Executive',30);
INSERT INTO Positions(pos_ID,name,pos_pay) VALUES ('CEO','CEO',40);

-- Retirement  ---------------------------------------------------
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Traditional 401(k) pre-50',10,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Traditional 401(k) post-50',15,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Roth 401(k) pre-50',7,FALSE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Roth 401(k) post-50',8,FALSE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Traditional IRA pre-50',5,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Traditional IRA post-50',6,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Roth IRA pre-50',7,FALSE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Roth IRA post-50',8,FALSE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Simplified Employee Pension Plan',17,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('403 (b)',13,TRUE);
INSERT INTO Retirement(r_plan,percent,pre_tax) VALUES ('Not Applicable',0,FALSE);

-- Tax ---------------------------------------------------
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Income Tax 1',1, 0, 6000);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Income Tax 2',2, 6000, 8000);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Income Tax 3',3, 8000, NULL);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Social Security Tax',2, NULL, NULL);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('State Tax 1',0.2, 0, 5000);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('State Tax 2',0.5, 5000, 7000);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('State Tax 3',1, 7000, NULL);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Local Tax 1',0.5, 0, 10000);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Local Tax 2',1, 10000, NULL);
INSERT INTO Tax(name,percent,min_pay,max_pay) VALUES ('Medicare Tax',1, NULL, NULL);


-- Employee ---------------------------------------------------
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('1','Michael West','Male',56,'alexamartinez@example.com','2023-02-19','4938966574',FALSE,'2363635846','Truist Financial','Savings','NA','CEO','HL','Roth 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('2','Samuel Monroe','Male',30,'ggoodman@example.net','2023-02-25','4778016973',TRUE,'4122782825','PNC Bank','Checking','F08','DS','AS1','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('3','Timothy Harris','Male',28,'debbieellis@example.org','2023-01-18','6597837495',TRUE,'8466111803','Santander','Savings','F08','DS','AS1','403 (b)',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('4','Cassandra Boyd','Female',32,'raykimberly@example.com','2023-03-09','1564985269',TRUE,'7944732371','Goldman Sachs','Savings','IT02','DS','AS1','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('5','Timothy Melendez','Male',33,'stephen77@example.net','2023-03-18','5406999328',TRUE,'9931278947','Capital One','Savings','O56','HRA','AS1','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('6','Ms. Brandi Jones','Female',26,'amberpreston@example.com','2023-02-01','2606143397',FALSE,'8954835349','Capital One','Checking','LL01','RC','AS1','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('7','Lacey Navarro','Female',27,'elliottderrick@example.com','2023-02-14','1703457120',FALSE,'1971835392','Wells Fargo','Savings','SL65','SC','AS1','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('8','Benjamin Hudson','Male',33,'phillipsanthony@example.org','2023-03-15','9376036819',TRUE,'1878587567','Santander','Checking','M87','DA','AS2','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('9','Laura Santana','Female',32,'mary05@example.org','2023-03-09','8249315123',TRUE,'9017737153','Citi Bank','Checking','F08','RC','AS2','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('10','Earla Price','Female',33,'howelldawn@example.net','2023-03-06','4333816842',TRUE,'8835431320','PNC Bank','Checking','LL01','LC','AS2','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('11','Katelyn Flynn','Female',31,'jacksonstephanie@example.com','2023-01-13','3236170837',TRUE,'7234615717','Chase Bank','Savings','LL01','LC','AS2','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('12','Lori Harris','Female',30,'corey56@example.org','2023-03-25','9758519013',TRUE,'5134302513','Citi Bank','Checking','SL65','SE','AS2','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('13','James Garcia','Male',24,'cynthiaestrada@example.com','2023-01-28','8849572476',FALSE,'2981470996','Wells Fargo','Checking','H01','ACC','EL','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('14','Kimberly Tapin','Female',25,'perrythomas@example.org','2023-03-25','4881257367',FALSE,'8069952132','Bank of America','Savings','CS78','CS','EL','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('15','Christopher Donovan','Male',24,'allencatherine@example.com','2023-03-02','5876105046',FALSE,'7071190983','Capital One','Savings','CS78','CS','EL','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('16','Jose Bradley','Male',52,'emilypatterson@example.com','2023-02-28','4847409832',TRUE,'9085484017','Bank of America','Checking','LL01','DI','HL','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('17','Tommy Wong','Male',51,'trevorsanders@example.org','2023-02-14','4420882289',TRUE,'1530618370','Bank of America','Checking','O56','DI','HL','Traditional IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('18','Laura Gentry','Female',55,'michaelroberts@example.org','2023-01-08','9956323416',TRUE,'8332707996','Truist Financial','Savings','SL65','DI','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('19','Matthew Chambers','Male',53,'angelajackson@example.net','2023-03-12','7658684887',TRUE,'4705150091','Santander','Savings','LL01','EE','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('20','Timothy Jackson','Male',45,'ybrown@example.net','2023-02-01','5515344181',TRUE,'6618084394','Capital One','Checking','M87','EE','HL','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('21','Amanda Smith','Female',54,'jcraig@example.com','2023-02-01','1871241447',TRUE,'2087103368','Capital One','Checking','LL01','VI','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('22','Matthew Lawson','Male',56,'hosborne@example.org','2023-03-05','9614632998',TRUE,'9086147474','Citi Bank','Savings','RD65','VI','HL','Roth 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('23','Jessica Ford','Female',54,'bbyrd@example.net','2023-03-13','7243759249',FALSE,'2897840239','Goldman Sachs','Savings','M87','VI','HL','Traditional IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('24','Mark Vasquez','Male',53,'andersonkatie@example.org','2023-02-25','1891796718',TRUE,'1793881710','Chase Bank','Checking','IT02','VI','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('25','Michael Crawford','Male',21,'andrea33@example.net','2023-03-24','9729229346',FALSE,'7886058634','PNC Bank','Savings','LL01','ACC','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('26','Kristie Ford','Female',22,'olsonjohn@example.com','2023-01-02','5762636174',FALSE,'5268060108','Santander','Checking','O56','DS','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('27','Daniel Davis','Male',21,'millerkevin@example.org','2023-01-06','9445165272',FALSE,'1153931824','U.S. Bank','Checking','SL65','FA','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('28','Jennifer Hansen','Female',51,'andrew03@example.com','2023-01-15','9149828351',TRUE,'4523010269','Wells Fargo','Savings','RD65','DI','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('29','Audrey Melton','Female',22,'gomezjustin@example.com','2023-01-13','3022142957',FALSE,'8986096303','PNC Bank','Checking','F08','RC','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('30','Edward Contreras','Male',23,'tuckerpamela@example.org','2023-01-25','3988564933',FALSE,'3628750833','Bank of America','Savings','RD65','OA','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('31','Daniel Miller','Male',25,'katherinesheppard@example.net','2023-03-22','8330674428',FALSE,'8936231850','U.S. Bank','Checking','F08','BA','JU','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('32','Emily Ortega','Female',25,'nicholsonerica@example.com','2023-01-07','7432749100',FALSE,'4470249239','Goldman Sachs','Savings','LL01','RC','JU','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('33','Robin Roberts','Female',26,'alexandria91@example.net','2023-03-26','5205879645',FALSE,'1006789986','Chase Bank','Checking','IT02','TES','JU','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('34','Ryan Wilson','Male',25,'wardshawn@example.net','2023-03-23','7075798574',FALSE,'5490354768','PNC Bank','Savings','A51','OA','JU','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('35','Darlene Peterson','Female',26,'wanderson@example.net','2023-01-19','3751434706',FALSE,'8258568023','U.S. Bank','Savings','M87','SC','JU','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('36','Emily Ross','Female',30,'andrewbarnes@example.net','2023-03-18','7657171838',TRUE,'4294379963','Bank of America','Checking','F08','BA','LE','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('37','Robert Conway','Male',29,'david40@example.net','2023-03-21','5123653209',FALSE,'4573596487','Citi Bank','Checking','CS78','CS','LE','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('38','Kenneth Holmes','Male',31,'allisonjohnson@example.net','2023-02-05','9742656117',TRUE,'5878025845','Santander','Checking','IT02','GD','LE','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('39','Elizabeth Zimmerman','Female',56,'james34@example.com','2023-01-18','8791786307',TRUE,'7532959755','Goldman Sachs','Checking','IT02','DI','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('40','William Cunningham','Male',56,'jenniferbautista@example.org','2023-02-03','8239138603',FALSE,'2518681304','Santander','Checking','M87','DI','HL','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('41','Nicole Flores','Female',32,'aimeekelly@example.net','2023-02-19','7896382125',TRUE,'8979273911','Chase Bank','Checking','CS78','RC','LE','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('42','Bob Garcia','Female',31,'sweeneydavid@example.org','2023-02-03','5667760951',TRUE,'4766895640','PNC Bank','Checking','M87','OA','LE','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('43','Debra Smith','Female',29,'boyletimothy@example.net','2023-01-22','2298447203',TRUE,'5776996939','Chase Bank','Savings','RD65','RE','LE','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('44','Tasha Burns','Female',35,'leblancbonnie@example.org','2023-02-07','3147716902',FALSE,'6111920251','Capital One','Checking','H01','HRA','MA','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('45','Joseph Bradley','Male',52,'michael89@example.org','2023-01-22','4744348135',TRUE,'1570015858','Chase Bank','Checking','IT02','EE','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('46','Daniel Hogan','Male',49,'kelly50@example.com','2023-02-03','3243454164',TRUE,'5312619071','Chase Bank','Savings','A51','DI','HL','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('47','Omar Ferguson','Male',49,'jimenezcalvin@example.net','2023-03-10','1198168828',TRUE,'2342094845','Goldman Sachs','Checking','F08','DI','HL','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('48','Manuel Johnson','Male',46,'jcastillo@example.net','2023-02-02','2378170698',TRUE,'6121944541','U.S. Bank','Checking','CS78','RC','SP','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('49','Christopher Thomas','Male',38,'amanda27@example.com','2023-02-11','3882455823',TRUE,'2171040915','Santander','Checking','CS78','RC','SP','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('50','Stephen Bradley','Male',37,'castillofrank@example.net','2023-02-05','3207873733',FALSE,'6662849574','Santander','Checking','A51','OA','SP','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('51','James Espinoza','Male',26,'veronica58@example.com','2023-02-18','1735620429',FALSE,'9127122242','Truist Financial','Checking','RD65','RE','JU','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('52','Derrick Torres','Male',23,'ahall@example.com','2023-01-26','1558663601',FALSE,'3901232981','Bank of America','Checking','LL01','RC','AS1','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('53','Samantha Wilson','Female',58,'karenesparza@example.org','2023-02-04','5664848084',TRUE,'2683269674','Goldman Sachs','Checking','O56','EE','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('54','Kristie Benson','Female',34,'samuelruiz@example.com','2023-01-15','6636889684',TRUE,'4510886562','Truist Financial','Savings','SL65','MRA','LE','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('55','Maria Sullivan','Female',54,'xfarley@example.net','2023-03-17','3438636480',TRUE,'8295428906','Bank of America','Checking','CS78','DI','HL','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('56','Kevina Reed','Female',21,'lisahoward@example.com','2023-03-10','7293830307',FALSE,'1961189885','Goldman Sachs','Checking','H01','HRB','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('57','Andrea Smith','Female',35,'swalker@example.com','2023-02-01','2683957564',TRUE,'8151896308','PNC Bank','Checking','O56','DS','LE','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('58','Laura Flores','Female',44,'michael18@example.com','2023-03-25','1129983470',FALSE,'3041545544','PNC Bank','Checking','RD65','GD','SP','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('59','Lisa Torres','Female',39,'michellejoseph@example.com','2023-02-10','4632538452',FALSE,'3468224333','Truist Financial','Savings','IT02','HRB','SE','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('60','Glen Silva','Male',27,'nicole99@example.org','2023-01-31','4422048585',FALSE,'3789372578','U.S. Bank','Checking','A51','SC','JU','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('61','Edward Vasquez','Male',45,'nwright@example.com','2023-03-12','7831299927',TRUE,'7366750668','Bank of America','Checking','O56','VI','HL','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('62','David Gardner','Male',22,'fray@example.com','2023-01-25','7833164976',FALSE,'8676510043','Truist Financial','Savings','H01','HRB','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('63','Jessica Evans','Female',31,'vtaylor@example.net','2023-01-03','9924488511',TRUE,'3090061251','Goldman Sachs','Checking','O56','BA','LE','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('64','Carla Joseph','Female',33,'perezsusan@example.com','2023-03-04','3384083537',FALSE,'8825529426','Santander','Checking','O56','OA','AS2','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('65','Kevin Hutchinson','Male',46,'craigclements@example.org','2023-02-17','9888897104',FALSE,'6922377726','Capital One','Savings','O56','CS','SE','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('66','Allen Gay','Male',43,'andrewssonya@example.net','2023-03-17','4478233603',TRUE,'4251624056','Santander','Checking','SL65','DS','SE','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('67','Laura Snow','Female',37,'kjones@example.com','2023-02-07','7777163837',TRUE,'1840381733','PNC Bank','Checking','RD65','FA','MA','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('68','Donald Morris','Male',28,'sandra00@example.net','2023-03-01','9317962158',TRUE,'9225368829','Bank of America','Savings','RD65','RC','AS1','403 (b)',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('69','Nathan Graham','Male',29,'wilsonemma@example.com','2023-01-11','4640572126',TRUE,'8956449152','Chase Bank','Checking','IT02','RC','AS1','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('70','Gabriel Fleming','Male',23,'melissa05@example.org','2023-03-17','9593556607',FALSE,'9498435585','Bank of America','Checking','IT02','CS','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('71','Robert Sanchez','Male',41,'uallen@example.org','2023-01-03','6305320432',FALSE,'6939036170','Wells Fargo','Checking','O56','DS','SP','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('72','Jennifer Harper','Female',49,'sandra42@example.net','2023-02-19','3845362401',TRUE,'3039557201','Citi Bank','Checking','SL65','VI','HL','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('73','April Williams','Female',42,'davischeyenne@example.com','2023-03-04','8902579565',TRUE,'5957540284','Santander','Savings','H01','RC','SE','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('74','Tara Walker','Female',40,'zacharycarrillo@example.com','2023-03-08','9898081286',TRUE,'1067464491','Capital One','Checking','A51','OA','SP','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('75','Scott Anderson','Male',24,'ashleyjones@example.com','2023-02-08','1363626724',FALSE,'6067191149','Truist Financial','Checking','RD65','ACC','JU','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('76','Andrew Floyd','Male',26,'watersjennifer@example.com','2023-03-03','6947304439',FALSE,'1969549862','Wells Fargo','Savings','F08','BA','EL','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('77','Jesse Gay','Male',25,'davidwells@example.com','2023-01-13','7449876106',FALSE,'2576124271','Chase Bank','Checking','M87','MRA','JU','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('78','Michael Marquez','Male',32,'veronicaturner@example.com','2023-01-09','3965663196',TRUE,'8640187694','Capital One','Savings','IT02','DS','AS2','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('79','Jonathan Salazar','Male',52,'yburke@example.org','2023-02-03','6348227727',FALSE,'3872118270','Truist Financial','Checking','H01','DI','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('80','Kelsey Hughes','Female',55,'georgegill@example.org','2023-03-29','9175836491',TRUE,'5341281639','Capital One','Checking','A51','VI','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('81','Donna Norman','Female',55,'uhughes@example.org','2023-02-23','7103217717',TRUE,'8723309920','U.S. Bank','Savings','A51','EE','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('82','Christopher Morton','Male',30,'christophersnow@example.net','2023-03-25','2118594780',FALSE,'7997790446','Goldman Sachs','Savings','SL65','HRB','AS1','Roth IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('83','Nicole Moss','Male',51,'pamela02@example.org','2023-03-04','5412211686',TRUE,'3082029167','Santander','Savings','RD65','EE','HL','Traditional 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('84','Spencer Woodward','Male',31,'jacksonwalter@example.com','2023-01-23','2082550715',TRUE,'7939798543','U.S. Bank','Checking','CS78','HRA','AS2','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('85','Mr. Larry Wade DDS','Male',58,'heatherreyes@example.org','2023-02-14','4184414029',TRUE,'3593393772','Goldman Sachs','Savings','F08','VI','HL','Roth 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('86','Brandy Elliott MD','Female',54,'wendy50@example.net','2023-03-06','6048301832',TRUE,'6309420888','Santander','Savings','SL65','EE','HL','Roth IRA post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('87','Alexander Rivera','Male',55,'fsimmons@example.org','2023-01-30','5226555608',TRUE,'5154717862','Goldman Sachs','Savings','CS78','EE','HL','Roth 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('88','Kyle Padilla','Female',55,'xbenson@example.com','2023-01-07','2645689727',FALSE,'8132511708','Santander','Savings','CS78','VI','HL','Roth 401(k) post-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('89','David Allen','Male',53,'ruizamy@example.net','2023-01-31','9823262051',TRUE,'4519858899','Chase Bank','Savings','H01','VI','HL','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('90','Johnathan Green','Male',48,'dudleysandra@example.com','2023-02-02','7007563175',TRUE,'6589329268','Truist Financial','Savings','H01','EE','HL','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('91','Julie Sexton','Female',39,'arthur98@example.org','2023-03-09','6970307272',TRUE,'2127966460','Truist Financial','Checking','CS78','CS','MA','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('92','Nicole Anderson','Female',41,'meaganwilliams@example.com','2023-02-20','8719383556',FALSE,'5105433614','Bank of America','Checking','RD65','GD','SP','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('93','Shawn Franco','Male',22,'arogers@example.org','2023-01-31','6465734977',FALSE,'6456009141','Bank of America','Checking','IT02','DA','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('94','Laurie Johnson','Female',23,'hector16@example.net','2023-02-24','4309260670',FALSE,'7528145504','Santander','Checking','O56','CS','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('95','Charles Hawkins','Male',45,'christopher31@example.net','2023-03-14','3889662004',TRUE,'4572079205','Chase Bank','Checking','F08','EE','HL','Traditional IRA pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('96','Stephen Zhang','Male',32,'joemaldonado@example.net','2023-03-15','3255992861',TRUE,'8239165449','PNC Bank','Savings','SL65','HRB','LE','Traditional 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('97','Julie Delgado','Female',27,'hward@example.net','2023-01-18','2081885552',FALSE,'1146208285','Goldman Sachs','Savings','O56','DS','AS1','Roth 401(k) pre-50',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('98','Paul Munoz','Male',23,'jeffreydawson@example.org','2023-03-23','4588269668',FALSE,'3740545127','Bank of America','Savings','SL65','HRB','IN','Not Applicable',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('99','Kevin Solis','Male',30,'cathy20@example.com','2023-03-24','6086370835',TRUE,'6560129869','Bank of America','Checking','M87','DS','LE','Simplified Employee Pension Plan',0);
INSERT INTO Employee(emp_ID,full_name,gender,age,email,join_date,contact_num,has_child,account_num,bank_name,acc_type,dept_ID,pos_ID,grade_ID,r_plan,amount) VALUES ('100','Angela Bishop','Female',25,'copelandallison@example.org','2023-02-10','8599339588',FALSE,'8602605839','U.S. Bank','Savings','SL65','MRA','JU','Traditional IRA pre-50',0);

-- Takes_leave ---------------------------------------------------
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('1',800,'2023-08-01 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('1',300,'2023-05-01 00:00:00','2023-05-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('1',400,'2023-05-22 00:00:00','2023-05-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('1',800,'2023-03-15 00:00:00','2023-03-23 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('1',900,'2023-10-15 00:00:00','2023-10-22 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('2',200,'2023-05-01 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('2',300,'2023-04-01 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('2',400,'2023-07-01 00:00:00','2023-07-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('2',500,'2023-08-01 00:00:00','2023-08-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('2',900,'2023-09-01 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('3',200,'2023-02-01 00:00:00','2023-02-28 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('3',300,'2023-05-15 00:00:00','2023-06-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('3',400,'2023-06-07 00:00:00','2023-06-14 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('3',500,'2023-07-01 00:00:00','2023-07-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('3',600,'2023-08-05 00:00:00','2023-08-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('4',100,'2023-03-15 00:00:00','2023-04-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('4',300,'2023-06-01 00:00:00','2023-06-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('4',400,'2023-05-14 00:00:00','2023-05-21 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('4',500,'2023-05-01 00:00:00','2023-05-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('5',200,'2023-06-01 00:00:00','2023-06-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('5',400,'2023-05-21 00:00:00','2023-05-28 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('5',400,'2023-04-01 00:00:00','2023-04-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('5',500,'2023-05-01 00:00:00','2023-05-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('5',600,'2023-05-15 00:00:00','2023-05-17 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('6',300,'2023-07-01 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('6',400,'2023-05-28 00:00:00','2023-06-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('6',500,'2023-05-01 00:00:00','2023-05-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('6',600,'2023-05-20 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('6',600,'2023-03-01 00:00:00','2023-03-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('7',300,'2023-07-15 00:00:00','2023-08-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('7',400,'2023-06-04 00:00:00','2023-06-11 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('7',500,'2023-05-01 00:00:00','2023-05-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('7',600,'2023-05-25 00:00:00','2023-05-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',200,'2023-06-15 00:00:00','2023-07-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',300,'2023-08-01 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',300,'2023-03-20 00:00:00','2023-03-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',400,'2023-06-11 00:00:00','2023-06-18 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',500,'2023-05-01 00:00:00','2023-05-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',600,'2023-05-30 00:00:00','2023-06-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('8',800,'2023-04-15 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',100,'2023-02-15 00:00:00','2023-03-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',200,'2023-07-01 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',300,'2023-08-15 00:00:00','2023-09-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',400,'2023-06-18 00:00:00','2023-06-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',500,'2023-05-01 00:00:00','2023-05-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('9',600,'2023-06-04 00:00:00','2023-06-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('10',100,'2023-04-05 00:00:00','2023-05-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('10',300,'2023-09-01 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('10',400,'2023-06-25 00:00:00','2023-07-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('10',500,'2023-05-20 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('10',600,'2023-06-09 00:00:00','2023-06-14 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('11',100,'2023-02-15 00:00:00','2023-03-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('11',300,'2023-09-15 00:00:00','2023-10-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('11',400,'2023-07-02 00:00:00','2023-07-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('11',500,'2023-05-01 00:00:00','2023-05-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('11',600,'2023-06-14 00:00:00','2023-06-19 00:00:00');

INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',600,'2023-04-10 00:00:00','2023-04-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',500,'2023-05-11 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',600,'2023-06-19 00:00:00','2023-06-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',400,'2023-07-09 00:00:00','2023-07-16 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',100,'2023-08-15 00:00:00','2023-10-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('12',300,'2023-11-01 00:00:00','2023-11-15 00:00:00');

INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('13',300,'2023-10-15 00:00:00','2023-11-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('13',400,'2023-07-16 00:00:00','2023-07-23 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('13',600,'2023-06-24 00:00:00','2023-06-29 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('14',300,'2023-11-01 00:00:00','2023-11-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('14',300,'2023-04-01 00:00:00','2023-04-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('14',400,'2023-07-23 00:00:00','2023-07-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('14',500,'2023-05-01 00:00:00','2023-05-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('14',600,'2023-06-29 00:00:00','2023-07-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('15',300,'2023-11-15 00:00:00','2023-12-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('15',400,'2023-07-30 00:00:00','2023-08-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('15',500,'2023-05-21 00:00:00','2023-05-22 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('15',600,'2023-07-04 00:00:00','2023-07-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('16',200,'2023-09-01 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('16',300,'2023-12-01 00:00:00','2023-12-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('16',300,'2023-03-15 00:00:00','2023-04-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('16',400,'2023-08-06 00:00:00','2023-08-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('16',600,'2023-07-09 00:00:00','2023-07-14 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('17',200,'2023-09-15 00:00:00','2023-10-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('17',300,'2023-12-15 00:00:00','2023-12-31 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('17',400,'2023-08-13 00:00:00','2023-08-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('17',600,'2023-07-14 00:00:00','2023-07-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('18',100,'2023-02-01 00:00:00','2023-04-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('18',300,'2023-05-01 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('18',400,'2023-08-20 00:00:00','2023-08-27 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('18',600,'2023-07-19 00:00:00','2023-07-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('18',900,'2023-10-01 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('19',300,'2023-05-15 00:00:00','2023-06-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('19',400,'2023-08-27 00:00:00','2023-09-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('19',600,'2023-07-24 00:00:00','2023-07-29 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('20',200,'2023-11-01 00:00:00','2023-11-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('20',300,'2023-06-01 00:00:00','2023-06-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('20',400,'2023-09-03 00:00:00','2023-09-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('20',600,'2023-07-29 00:00:00','2023-08-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('20',1000,'2023-04-01 00:00:00','2023-04-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('21',100,'2023-11-15 00:00:00','2023-12-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('21',300,'2023-06-15 00:00:00','2023-07-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('21',400,'2023-09-10 00:00:00','2023-09-17 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('21',600,'2023-08-03 00:00:00','2023-08-08 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('21',600,'2023-03-01 00:00:00','2023-03-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('22',300,'2023-07-01 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('22',400,'2023-09-17 00:00:00','2023-09-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('22',600,'2023-08-08 00:00:00','2023-08-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('22',800,'2023-03-15 00:00:00','2023-04-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('23',300,'2023-07-15 00:00:00','2023-08-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('23',400,'2023-09-24 00:00:00','2023-10-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('23',500,'2023-05-01 00:00:00','2023-05-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('23',600,'2023-08-13 00:00:00','2023-08-18 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('24',200,'2023-12-15 00:00:00','2023-12-31 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('24',300,'2023-08-01 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('24',400,'2023-10-01 00:00:00','2023-10-08 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('24',400,'2023-03-01 00:00:00','2023-03-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('25',300,'2023-08-15 00:00:00','2023-09-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('25',400,'2023-10-08 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('25',500,'2023-05-01 00:00:00','2023-05-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('26',300,'2023-09-01 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('26',400,'2023-10-15 00:00:00','2023-10-22 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('26',500,'2023-05-20 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('26',800,'2023-05-01 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('27',300,'2023-09-15 00:00:00','2023-10-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('27',400,'2023-10-22 00:00:00','2023-10-29 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('27',400,'2023-04-05 00:00:00','2023-04-12 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('27',500,'2023-05-01 00:00:00','2023-05-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('27',800,'2023-05-15 00:00:00','2023-06-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('28',100,'2023-02-15 00:00:00','2023-03-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('28',300,'2023-10-01 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('28',400,'2023-10-29 00:00:00','2023-11-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('28',500,'2023-02-01 00:00:00','2023-02-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('28',900,'2023-06-01 00:00:00','2023-06-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('29',300,'2023-10-15 00:00:00','2023-11-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('29',400,'2023-11-05 00:00:00','2023-11-12 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('29',500,'2023-05-01 00:00:00','2023-05-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('29',600,'2023-03-01 00:00:00','2023-03-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('29',900,'2023-06-15 00:00:00','2023-07-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('30',300,'2023-11-01 00:00:00','2023-11-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('30',300,'2023-04-10 00:00:00','2023-04-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('30',400,'2023-11-12 00:00:00','2023-11-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('30',400,'2023-04-01 00:00:00','2023-04-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('30',600,'2023-07-01 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('31',300,'2023-11-15 00:00:00','2023-12-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('31',300,'2023-03-22 00:00:00','2023-04-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('31',400,'2023-04-19 00:00:00','2023-04-26 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('31',500,'2023-05-01 00:00:00','2023-05-11 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('31',800,'2023-07-15 00:00:00','2023-08-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('32',300,'2023-12-01 00:00:00','2023-12-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('32',400,'2023-11-26 00:00:00','2023-12-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('32',500,'2023-06-01 00:00:00','2023-07-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('33',300,'2023-12-15 00:00:00','2023-12-31 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('33',300,'2023-04-01 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('33',400,'2023-12-03 00:00:00','2023-12-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('33',500,'2023-05-01 00:00:00','2023-05-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('33',900,'2023-08-01 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('34',300,'2023-05-12 00:00:00','2023-05-31 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('34',800,'2023-07-01 00:00:00','2023-07-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('35',600,'2023-04-05 00:00:00','2023-04-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('35',400,'2023-04-21 00:00:00','2023-04-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('36',100,'2023-07-01 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('36',400,'2023-09-10 00:00:00','2023-09-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('37',900,'2023-04-02 00:00:00','2023-04-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('38',1000,'2023-07-04 00:00:00','2023-07-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('39',300,'2023-04-05 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('40',300,'2023-06-20 00:00:00','2023-07-02 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('40',300,'2023-08-02 00:00:00','2023-08-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('40',500,'2023-10-07 00:00:00','2023-10-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('41',700,'2023-05-07 00:00:00','2023-05-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('42',700,'2023-05-07 00:00:00','2023-05-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('43',700,'2023-05-07 00:00:00','2023-05-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('44',900,'2023-04-13 00:00:00','2023-04-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('45',200,'2023-03-30 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('46',300,'2023-07-08 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('47',300,'2023-07-08 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('48',300,'2023-07-08 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('49',300,'2023-07-08 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('50',800,'2023-04-02 00:00:00','2023-04-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('51',400,'2023-05-03 00:00:00','2023-05-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('52',400,'2023-05-03 00:00:00','2023-05-06 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('53',300,'2023-08-01 00:00:00','2023-08-23 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('54',100,'2023-04-20 00:00:00','2023-05-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('55',100,'2023-09-11 00:00:00','2023-09-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('56',800,'2023-10-12 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('57',600,'2023-09-11 00:00:00','2023-09-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('58',900,'2023-04-13 00:00:00','2023-04-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('59',900,'2023-04-13 00:00:00','2023-04-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('60',600,'2023-09-11 00:00:00','2023-09-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('61',200,'2023-03-30 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('62',400,'2023-09-24 00:00:00','2023-09-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('62',400,'2023-10-14 00:00:00','2023-10-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('63',500,'2023-11-01 00:00:00','2023-11-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('64',500,'2023-11-01 00:00:00','2023-11-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('65',500,'2023-11-01 00:00:00','2023-11-03 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('66',200,'2023-10-01 00:00:00','2023-10-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('67',600,'2023-05-02 00:00:00','2023-05-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('68',200,'2023-08-01 00:00:00','2023-08-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('68',300,'2023-04-24 00:00:00','2023-05-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('68',800,'2023-10-12 00:00:00','2023-11-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('69',200,'2023-10-15 00:00:00','2023-10-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('69',600,'2023-02-21 00:00:00','2023-02-28 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('69',800,'2023-03-12 00:00:00','2023-04-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('70',300,'2023-03-03 00:00:00','2023-03-13 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('70',300,'2023-05-28 00:00:00','2023-06-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('70',600,'2023-02-21 00:00:00','2023-02-28 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('71',600,'2023-08-06 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('71',600,'2023-09-20 00:00:00','2023-09-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('72',500,'2023-04-05 00:00:00','2023-04-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('72',800,'2023-08-15 00:00:00','2023-08-24 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('73',300,'2023-05-25 00:00:00','2023-06-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('73',600,'2023-08-12 00:00:00','2023-08-17 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('74',600,'2023-08-05 00:00:00','2023-08-11 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('75',700,'2023-08-11 00:00:00','2023-08-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('75',900,'2023-06-25 00:00:00','2023-07-01 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('76',300,'2023-05-20 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('76',400,'2023-10-01 00:00:00','2023-10-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('76',500,'2023-10-15 00:00:00','2023-10-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('76',800,'2023-08-01 00:00:00','2023-08-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('76',1000,'2023-09-10 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',300,'2023-04-20 00:00:00','2023-04-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',400,'2023-05-01 00:00:00','2023-05-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',400,'2023-08-20 00:00:00','2023-08-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',600,'2023-09-01 00:00:00','2023-09-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',600,'2023-10-01 00:00:00','2023-10-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('77',700,'2023-11-10 00:00:00','2023-11-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',200,'2023-05-15 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',400,'2023-06-01 00:00:00','2023-06-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',800,'2023-08-15 00:00:00','2023-08-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',800,'2023-10-01 00:00:00','2023-10-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',1000,'2023-09-01 00:00:00','2023-09-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('78',1000,'2023-10-15 00:00:00','2023-10-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',200,'2023-09-25 00:00:00','2023-09-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',200,'2023-10-25 00:00:00','2023-10-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',300,'2023-08-10 00:00:00','2023-08-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',300,'2023-10-01 00:00:00','2023-10-07 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',500,'2023-05-20 00:00:00','2023-05-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('79',1000,'2023-05-10 00:00:00','2023-05-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',300,'2023-08-15 00:00:00','2023-08-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',300,'2023-10-15 00:00:00','2023-10-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',400,'2023-06-10 00:00:00','2023-06-20 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',500,'2023-09-01 00:00:00','2023-09-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',500,'2023-10-01 00:00:00','2023-10-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('80',900,'2023-06-25 00:00:00','2023-06-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',200,'2023-07-01 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',400,'2023-06-15 00:00:00','2023-06-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',600,'2023-08-25 00:00:00','2023-08-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',600,'2023-10-25 00:00:00','2023-10-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',700,'2023-09-10 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('81',700,'2023-10-10 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('82',300,'2023-06-15 00:00:00','2023-06-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('82',500,'2023-07-01 00:00:00','2023-07-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('82',800,'2023-08-15 00:00:00','2023-08-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('82',1000,'2023-09-01 00:00:00','2023-09-11 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('82',1000,'2023-10-01 00:00:00','2023-10-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',200,'2023-08-25 00:00:00','2023-08-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',300,'2023-09-10 00:00:00','2023-09-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',300,'2023-10-10 00:00:00','2023-10-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',600,'2023-06-25 00:00:00','2023-06-30 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',700,'2023-07-10 00:00:00','2023-07-14 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('83',800,'2023-10-25 00:00:00','2023-10-26 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('84',200,'2023-05-02 00:00:00','2023-05-09 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('84',200,'2023-07-03 00:00:00','2023-07-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('85',300,'2023-06-17 00:00:00','2023-06-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('86',300,'2023-06-17 00:00:00','2023-06-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('87',900,'2023-10-12 00:00:00','2023-10-19 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('88',600,'2023-08-08 00:00:00','2023-08-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('89',700,'2023-07-07 00:00:00','2023-07-08 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('90',400,'2023-04-02 00:00:00','2023-04-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('91',100,'2023-04-02 00:00:00','2023-05-04 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('92',400,'2023-04-02 00:00:00','2023-04-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('93',400,'2023-04-02 00:00:00','2023-04-05 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('94',400,'2023-04-21 00:00:00','2023-04-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('95',500,'2023-08-19 00:00:00','2023-08-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('96',300,'2023-06-17 00:00:00','2023-06-25 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('97',300,'2023-09-01 00:00:00','2023-09-15 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('98',800,'2023-06-07 00:00:00','2023-06-10 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('99',900,'2023-10-11 00:00:00','2023-10-11 00:00:00');
INSERT INTO Takes_Leave(emp_ID,leave_ID,start_date,end_date) VALUES ('100',900,'2023-10-11 00:00:00','2023-10-11 00:00:00');

-- Attendance ---------------------------------------------------
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,3,2023,22,154);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,5,2023,23,138);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,8,2023,16,128);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,10,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (1,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,4,2023,20,140);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,5,2023,1,9);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,7,2023,24,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,8,2023,29,232);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,9,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (2,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,2,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,5,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,6,2023,21,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,7,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,8,2023,25,225);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (3,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,3,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,4,2023,15,105);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,5,2023,21,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,6,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (4,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,4,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,5,2023,18,108);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,6,2023,15,135);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (5,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,3,2023,26,234);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,5,2023,18,108);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,6,2023,26,234);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,7,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (6,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,5,2023,19,152);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,6,2023,22,154);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,7,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,8,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (7,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,3,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,4,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,5,2023,11,99);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,6,2023,2,12);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,7,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,8,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (8,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,2,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,3,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,5,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,6,2023,16,128);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,7,2023,16,96);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,8,2023,14,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,9,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (9,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,4,2023,4,28);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,5,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,6,2023,18,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,7,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,9,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (10,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,2,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,3,2023,16,96);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,5,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,6,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,7,2023,23,161);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,9,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,10,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (11,12,2023,31,186);

INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,4,2023,24,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,5,2023,26,156);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,6,2023,24,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,7,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,8,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,9,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,10,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,11,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (12,12,2023,31,248);

INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,6,2023,24,192);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,7,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,10,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,11,2023,29,232);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (13,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,4,2023,10,70);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,5,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,6,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,7,2023,19,171);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,11,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (14,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,5,2023,29,232);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,7,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,8,2023,25,175);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,11,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (15,12,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,3,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,4,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,7,2023,25,175);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,8,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,9,2023,15,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (16,12,2023,16,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,7,2023,25,200);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,8,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,9,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,10,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (17,12,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,2,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,3,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,4,2023,29,232);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,5,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,7,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,8,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,10,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (18,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,5,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,6,2023,29,203);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,7,2023,25,200);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,8,2023,26,234);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,9,2023,27,162);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (19,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,4,2023,25,175);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,6,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,7,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,8,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,9,2023,22,154);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,11,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (20,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,3,2023,25,200);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,6,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,7,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,8,2023,25,225);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,9,2023,22,132);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,11,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (21,12,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,3,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,4,2023,15,135);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,7,2023,16,128);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,8,2023,25,200);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,9,2023,22,176);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (22,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,5,2023,26,182);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,7,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,8,2023,24,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,9,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,10,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (23,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,3,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,8,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,10,2023,23,138);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (24,12,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,5,2023,27,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,8,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,9,2023,29,203);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,10,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (25,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,5,2023,10,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,9,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,10,2023,23,138);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (26,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,4,2023,22,176);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,5,2023,10,70);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,6,2023,29,203);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,9,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,10,2023,22,198);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (27,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,2,2023,12,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,3,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,6,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,10,2023,13,91);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,11,2023,25,200);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (28,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,3,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,5,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,6,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,7,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,10,2023,14,84);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,11,2023,21,147);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (29,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,4,2023,15,135);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,7,2023,16,96);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,11,2023,7,56);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (30,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,3,2023,21,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,4,2023,21,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,5,2023,20,140);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,7,2023,14,98);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,8,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,11,2023,14,112);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (31,12,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,6,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,7,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,11,2023,25,225);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (32,12,2023,13,117);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,4,2023,20,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,5,2023,21,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,8,2023,16,96);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (33,12,2023,6,48);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,5,2023,11,88);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,7,2023,26,182);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (34,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,4,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (35,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,7,2023,0,0);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,8,2023,16,96);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,9,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (36,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,4,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (37,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,7,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (38,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,4,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (39,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,6,2023,19,133);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,7,2023,29,174);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,8,2023,22,176);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,10,2023,27,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (40,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,5,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (41,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,5,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (42,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,5,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (43,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,4,2023,23,138);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (44,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,3,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,4,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (45,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,7,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (46,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,7,2023,23,138);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (47,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,7,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (48,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,7,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (49,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,4,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (50,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,5,2023,27,243);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (51,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,5,2023,27,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (52,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,8,2023,8,56);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (53,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,4,2023,19,133);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,5,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (54,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,9,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (55,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,10,2023,27,162);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (56,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,9,2023,27,243);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (57,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,4,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (58,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,4,2023,23,161);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (59,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,9,2023,27,243);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (60,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,3,2023,29,174);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,4,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (61,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,9,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,10,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (62,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,11,2023,27,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (63,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,11,2023,27,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (64,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,11,2023,27,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (65,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,10,2023,11,77);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (66,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,5,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (67,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,4,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,5,2023,26,182);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,8,2023,11,99);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,10,2023,11,77);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,11,2023,29,203);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (68,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,2,2023,20,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,3,2023,11,77);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,4,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,10,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (69,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,2,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,3,2023,20,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,5,2023,27,162);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,6,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (70,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,8,2023,21,147);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,9,2023,25,225);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (71,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,4,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,8,2023,21,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (72,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,5,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,6,2023,29,203);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,8,2023,25,225);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (73,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,8,2023,24,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (74,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,6,2023,24,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,7,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,8,2023,21,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (75,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,5,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,8,2023,1,6);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,9,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,10,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (76,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,4,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,5,2023,21,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,8,2023,20,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,9,2023,20,140);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,10,2023,21,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,11,2023,24,192);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (77,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,5,2023,20,120);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,6,2023,23,161);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,8,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,9,2023,23,207);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,10,2023,18,162);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (78,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,5,2023,19,171);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,8,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,9,2023,24,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,10,2023,18,162);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (79,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,1,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,3,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,6,2023,13,104);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,8,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,9,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,10,2023,10,80);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (80,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,5,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,6,2023,14,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,7,2023,16,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,8,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,9,2023,24,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,10,2023,19,152);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (81,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,6,2023,19,171);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,7,2023,21,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,8,2023,20,160);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,9,2023,19,114);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,10,2023,21,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (82,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,6,2023,24,192);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,7,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,8,2023,25,175);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,9,2023,20,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,10,2023,23,161);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (83,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,5,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,7,2023,18,144);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (84,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,6,2023,21,126);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,10,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (85,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,6,2023,21,147);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (86,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,7,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,10,2023,23,161);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (87,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,8,2023,23,184);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (88,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,7,2023,29,261);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (89,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,4,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (90,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,4,2023,1,8);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,5,2023,27,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (91,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,4,2023,26,234);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,9,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (92,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,2,2023,28,168);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,4,2023,26,234);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,8,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (93,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,4,2023,25,150);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,5,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,7,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (94,12,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,4,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,6,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,8,2023,24,216);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,10,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (95,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,6,2023,21,189);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,10,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,11,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (96,12,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,1,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,2,2023,28,196);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,4,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,6,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,8,2023,31,248);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,9,2023,15,90);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,11,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (97,12,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,2,2023,28,224);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,3,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,5,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,6,2023,26,208);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,7,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,8,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,9,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,10,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,11,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (98,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,1,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,3,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,4,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,6,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,9,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,10,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (99,12,2023,31,186);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,1,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,2,2023,28,252);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,3,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,4,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,5,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,6,2023,30,270);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,7,2023,31,279);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,8,2023,31,217);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,9,2023,30,210);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,10,2023,30,240);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,11,2023,30,180);
INSERT INTO Attendance(emp_ID,month_,year_,days_worked,hrs_worked) VALUES (100,12,2023,31,186);

-- Get Bonus ---------------------------------------------------
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Christmas Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Thanksgiving Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Labour Day Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Commuter Benefit');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Relocation Assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Lunch Coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Education');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Gym coupon');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Child care assistance');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('1','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('2','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('3','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('4','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('5','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('6','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('7','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('8','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('9','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('10','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('11','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('12','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('13','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('14','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('15','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('16','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('17','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('18','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('19','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('20','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('21','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('22','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('23','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('24','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('25','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('26','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('27','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('28','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('29','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('30','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('31','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('32','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('33','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('34','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('35','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('36','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('37','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('38','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('39','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('40','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('41','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('42','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('43','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('44','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('45','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('46','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('47','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('48','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('49','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('50','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('51','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('52','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('53','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('54','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('55','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('56','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('57','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('58','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('59','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('60','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('61','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('62','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('63','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('64','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('65','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('66','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('67','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('68','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('69','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('70','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('71','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('72','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('73','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('74','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('75','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('76','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('77','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('78','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('79','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('80','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('81','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('82','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('83','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('84','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('85','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('86','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('87','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('88','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('89','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('90','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('91','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('92','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('93','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('94','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('95','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('96','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('97','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('98','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('99','Signing Bonus');
INSERT INTO Get_Bonus(emp_ID,b_type) VALUES ('100','Signing Bonus');

-- Insures ---------------------------------------------------
INSERT INTO Insures(emp_id,i_type,amount) VALUES (100,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (71,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (19,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (44,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (91,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (11,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (92,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (43,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (59,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (93,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (77,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (32,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (21,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (45,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (29,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (60,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (92,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (10,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (48,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (34,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (84,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (70,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (94,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (64,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (87,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (71,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (63,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (11,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (80,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (36,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (1,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (20,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (58,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (25,'Disability Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (78,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (62,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (19,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (55,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (78,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (95,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (55,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (66,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (67,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (79,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (82,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (74,'Accidental Death and Dismemberment (AD&D) Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (55,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (81,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (41,'Disability Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (23,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (80,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (12,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (24,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (9,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (23,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (93,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (10,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (62,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (39,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (79,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (59,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (14,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (56,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (4,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (46,'Accidental Death and Dismemberment (AD&D) Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (74,'Disability Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (29,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (25,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (10,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (71,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (70,'Disability Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (89,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (31,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (55,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (52,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (5,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (2,'Travel Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (31,'Health Insurance 1',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (70,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (20,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (77,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (16,'Long-Term Care Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (64,'Accidental Death and Dismemberment (AD&D) Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (2,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (26,'Health Insurance 2',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (81,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (19,'Dental Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (100,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (38,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (17,'Health Insurance 3',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (64,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (87,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (99,'Life Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (22,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (95,'Critical Illness Insurance',0);
INSERT INTO Insures(emp_id,i_type,amount) VALUES (1,'Dental Insurance',0);