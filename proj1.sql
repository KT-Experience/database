------------------------------------------------------
-- COMP9311 26T3 Project 1
-- SQL and PL/pgSQL Template
-- Name:
-- zID:
------------------------------------------------------

-- Q1:
CREATE OR REPLACE VIEW filter_year AS 
SELECT pe.student, semesters.year, semesters.term,pe.program, semesters.id   
FROM program_enrolments as pe 
JOIN  semesters 
ON pe.semester=semesters.id 
WHERE semesters.year='2012' AND semesters.term='S1'; 

 
CREATE OR REPLACE VIEW eligible_student AS 
SELECT DISTINCT f.student 
FROM courses c  
JOIN course_enrolments as ce 
ON c.id =ce.course 
JOIN subjects s 
ON c.subject=s.id 
JOIN filter_year as f 
ON f.student=ce.student AND c.semester=f.id 
WHERE s.code LIKE 'MATH%' AND NOT EXISTS( 
	SELECT * 
	FROM orgunits o 
	JOIN programs p 
	ON p.offeredby = o.id 
	JOIN filter_year f2 
	ON f2.program=p.id	 
	WHERE o.name LIKE'Faculty of Science' 
AND f2.student = f.student 
); 

 

CREATE OR REPLACE VIEW inter_student AS 
SELECT DISTINCT student 
FROM filter_year 
INTERSECT 
SELECT student 
FROM eligible_student; 


CREATE OR REPLACE VIEW Q1(program_code, num_students) AS
SELECT p.code AS program_code, COUNT(DISTINCT i.student) AS num_students
FROM programs AS p
JOIN filter_year AS f
ON p.id = f.program
JOIN inter_student AS i
ON i.student = f.student
GROUP BY p.code
HAVING COUNT(DISTINCT i.student) >= 10;


-- Q2:
--CREATE OR REPLACE VIEW Q2(program_code, subject_code) AS
--... SQL statements, possibly using other views/functions defined by you ...
--;

-- Q3:

-- 1. Link teaching staff to subject
CREATE OR REPLACE VIEW q3_fullstaff AS
SELECT *
FROM course_staff cs
JOIN courses c
ON c.id=cs.course;

-- 2. suject that has 6 distinct teaching staff
CREATE OR REPLACE VIEW q3_6staff AS
SELECT qf.semester, qf.course, COUNT (DISTINCT qf.staff)
FROM q3_fullstaff qf
GROUP BY qf.semester,qf.course
HAVING COUNT(DISTINCT qf.staff)>6;

-- 3. Find affiliation of each these teaching staff
CREATE OR REPLACE VIEW q3_affi AS
SELECT qf.course 
FROM q3_fullstaff qf
JOIN q3_6staff q6
ON qf.course=q6.course AND qf.semester = q6.semester
JOIN affiliations a
ON a.staff=qf.staff
GROUP BY qf.course 
HAVING COUNT(DISTINCT a.orgunit) > 2;

-- 4. b) condition
CREATE OR REPLACE VIEW q3_affi2 AS
SELECT qf.course
FROM q3_fullstaff qf
JOIN affiliations a
ON a.staff=qf.staff
GROUP BY qf.course, qf.semester
HAVING COUNT(DISTINCT a.orgunit) <=1 AND COUNT(DISTINCT a.orgunit)!=0;

CREATE OR REPLACE VIEW Q3(subject_code) AS
SELECT s.code
FROM q3_affi qa
JOIN courses c  ON c.id = qa.course      
JOIN subjects s ON s.id = c.subject      
INTERSECT
 
SELECT s.code
FROM q3_affi2 qb
JOIN courses c  ON c.id = qb.course       
JOIN subjects s ON s.id = c.subject; 
;

-- Q4:
--CREATE OR REPLACE VIEW Q4(unsw_id, ug_code, pg_code) AS
--... SQL statements, possibly using other views/functions defined by you ...
--;

-- Q5:
--CREATE OR REPLACE VIEW Q5(program_code) AS
--... SQL statements, possibly using other views/functions defined by you ...
--;

-- Q6:
--CREATE OR REPLACE VIEW Q6(student_unswid, professor_unswid, num_subjects) AS
--... SQL statements, possibly using other views/functions defined by you ...
--;

-- Q7:
--CREATE OR REPLACE VIEW Q7(course_id, num_students) AS
--... SQL statements, possibly using other views/functions defined by you ...
--;

-- Q8:
--CREATE OR REPLACE FUNCTION Q8(program_code character(4), year integer, term character(2)) RETURNS SETOF text AS $$
--... SQL statements, possibly using other views/functions defined by you ...
--$$ language plpgsql;

-- Q9:
--CREATE OR REPLACE FUNCTION Q9(unswid integer, year integer, term character(2)) RETURNS text AS $$
--... SQL statements, possibly using other views/functions defined by you ...
--$$ language plpgsql;

-- Q10:
--CREATE OR REPLACE FUNCTION Q10(unswid integer) RETURNS SETOF text AS $$
--... SQL statements, possibly using other views/functions defined by you ...
--$$ language plpgsql;
