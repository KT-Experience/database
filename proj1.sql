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
--1. filter students by program
CREATE OR REPLACE VIEW q4_ug AS
SELECT pe.student,MAX(s.starting) as ug_fin,p.offeredby,p.code as ug_program_code 
FROM programs p 
JOIN program_enrolments pe 
ON pe.program=p.id
JOIN semesters s 
ON s.id=pe.semester
WHERE p.career='UG'  
GROUP BY pe.student,pe.program,p.offeredby,p.code;

CREATE OR REPLACE VIEW q4_pg AS
SELECT pe.student,MIN(s.starting) as pg_start,p.offeredby,p.code as pg_program_code
FROM programs p 
JOIN program_enrolments pe 
ON pe.program=p.id
JOIN semesters s 
ON s.id=pe.semester
WHERE p.career='PG'  
GROUP BY pe.student,pe.program,p.offeredby,p.code;

CREATE OR REPLACE VIEW q4_2degree AS
SELECT ug.student, ug.ug_program_code, pg.pg_program_code
FROM q4_ug ug
JOIN q4_pg pg
  ON ug.student = pg.student
WHERE ug.offeredby <> pg.offeredby
  AND ug.ug_fin < pg.pg_start;
 
 
--filter students by marks  
CREATE OR REPLACE VIEW q4_ug_s AS
SELECT degree.student, degree.ug_program_code
FROM q4_2degree degree
JOIN programs p            
ON p.code = degree.ug_program_code
JOIN program_enrolments pe 
ON pe.student = degree.student AND pe.program = p.id
JOIN courses c             
ON c.semester = pe.semester
JOIN course_enrolments ce  
ON ce.course = c.id AND ce.student = degree.student
GROUP BY degree.student, degree.ug_program_code
HAVING COUNT(DISTINCT ce.course) FILTER (WHERE ce.mark IS NOT NULL) >= 4 AND AVG(ce.mark) > 75;
 
CREATE OR REPLACE VIEW q4_pg_s AS
SELECT degree.student, degree.pg_program_code
FROM q4_2degree degree
JOIN programs p            
ON p.code = degree.pg_program_code
JOIN program_enrolments pe 
ON pe.student = degree.student AND pe.program = p.id
JOIN courses c            
ON c.semester = pe.semester
JOIN course_enrolments ce 
ON ce.course = c.id AND ce.student = degree.student
GROUP BY degree.student, degree.pg_program_code
HAVING COUNT(DISTINCT ce.course) FILTER (WHERE ce.mark IS NOT NULL) >= 4 AND AVG(ce.mark) > 70;

CREATE OR REPLACE VIEW Q4(unsw_id, ug_code, pg_code) AS
SELECT DISTINCT people.unswid as unsw_id, u.ug_program_code as ug_code, p.pg_program_code as pg_code
FROM q4_ug_s u
JOIN q4_pg_s p 
ON p.student = u.student
JOIN q4_2degree d 
ON d.student = u.student AND d.ug_program_code = u.ug_program_code
AND d.pg_program_code = p.pg_program_code
JOIN people 
ON people.id=u.student;


-- Q5:

-- 1. students who had classes in at least two 2011 semesters

CREATE OR REPLACE VIEW q5_student AS
SELECT ce.student 
FROM course_enrolments AS ce
JOIN courses AS c
ON c.id = ce.course
JOIN semesters AS se
ON se.id = c.semester
JOIN classes
ON classes.course = c.id
WHERE se.year = 2011 AND se.term IN ('X1', 'S1', 'S2')
GROUP BY ce.student
HAVING COUNT(DISTINCT se.term)>=2;


-- 2. room condition

CREATE OR REPLACE VIEW q5_filter_room AS
SELECT DISTINCT a.orgunit, c.id as course
FROM courses AS c
JOIN semesters AS se
ON se.id = c.semester
JOIN course_staff cs
ON cs.course = c.id
JOIN affiliations a
ON a.staff=cs.staff
WHERE a.isprimary = 't' AND se.year = 2011 AND se.term IN ('X1', 'S1', 'S2');


-- 3. link program 

CREATE OR REPLACE VIEW q5_prog_room AS
SELECT DISTINCT pe.program, ce.student, se.term, r.building, r.id as room
FROM q5_student qs
JOIN course_enrolments AS ce
ON ce.student = qs.student
JOIN courses AS c
ON c.id = ce.course
JOIN semesters AS se
ON se.id = c.semester
JOIN classes
ON classes.course = c.id
JOIN rooms r
ON r.id = classes.room
JOIN program_enrolments pe
ON pe.student=ce.student AND pe.semester=c.semester
JOIN programs p
ON p.id=pe.program
JOIN q5_filter_room qfr
ON qfr.orgunit=p.offeredby AND qfr.course=c.id;
 

-- 4.  facility condition 

CREATE OR REPLACE VIEW q5_room_faci AS
SELECT DISTINCT qpr.program, qpr.student, qpr.term, rf.facility
FROM q5_prog_room qpr
LEFT JOIN room_facilities rf
ON rf.room=qpr.room;


CREATE OR REPLACE VIEW q5_term_count AS
SELECT qrf.program, qrf.student, COUNT(DISTINCT qrf.term) as n_terms
FROM q5_room_faci qrf
GROUP BY qrf.program, qrf.student;

CREATE OR REPLACE VIEW q5_diff_faci AS
SELECT DISTINCT qrf.program, qrf.student
FROM q5_room_faci qrf
JOIN q5_term_count qtc
ON qtc.program=qrf.program AND qtc.student=qrf.student
WHERE qrf.facility IS NOT NULL
GROUP BY qrf.program, qrf.student, qrf.facility, qtc.n_terms
HAVING COUNT(DISTINCT qrf.term)<qtc.n_terms;

-- 5. building and semester condition 

CREATE OR REPLACE VIEW q5_two_building AS
SELECT qpr.program, qpr.student, qpr.term
FROM q5_prog_room qpr
GROUP BY qpr.program, qpr.student, qpr.term
HAVING COUNT(DISTINCT qpr.building)>=2;
 

CREATE OR REPLACE VIEW q5_two_semester AS
SELECT qtb.program, qtb.student
FROM q5_two_building qtb
GROUP BY qtb.program, qtb.student
HAVING COUNT(DISTINCT qtb.term)>=2;

-- 6. putting all together 

CREATE OR REPLACE VIEW Q5(program_code) AS
	SELECT p.code
	FROM (
		SELECT qdf.program, qdf.student
		FROM q5_diff_faci qdf
		INTERSECT
		SELECT qts.program, qts.student
		FROM q5_two_semester qts
	) qbo
	JOIN programs p
	ON p.id=qbo.program
	GROUP BY p.id, p.code
	HAVING COUNT(DISTINCT qbo.student)>=20;

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
