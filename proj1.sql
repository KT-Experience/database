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

--1. A student without a stream enrolments has no first stream semester.

CREATE OR REPLACE VIEW q6_filter_starting_day AS
SELECT pe.student, MIN(starting) as starting
FROM program_enrolments pe
JOIN semesters s 
ON pe.semester=s.id 
JOIN stream_enrolments se 
ON se.partof=pe.id 
JOIN streams st 
ON st.id=se.stream
GROUP BY pe.student;

CREATE OR REPLACE VIEW q6_first_stream AS
SELECT q.student,s.id as semester
FROM q6_filter_starting_day q
JOIN semesters s 
ON s.starting=q.starting; 

--2. The student’s average mark before their first stream semesters is greater than 75.

CREATE OR REPLACE VIEW q6_avg AS
SELECT ce.student
FROM q6_filter_starting_day qs 
JOIN course_enrolments ce 
ON ce.student=qs.student
JOIN courses c
ON c.id=ce.course
JOIN semesters se 
ON se.id=c.semester 
WHERE se.starting<qs.starting AND ce.mark IS NOT NULL
GROUP BY ce.student 
HAVING AVG(ce.mark)>75;


-- 3. The student is enrolled in at least one course for which the professor is a course lecturer.
 
CREATE OR REPLACE VIEW q6_ini_pair AS
SELECT DISTINCT ce.student, cs.staff
FROM q6_avg qv
JOIN course_enrolments ce
ON ce.student=qv.student
JOIN course_staff cs
ON cs.course=ce.course
JOIN staff_roles sr
ON sr.id=cs.role
WHERE sr.name='Course Lecturer';

-- Q6:

--1. A student without a stream enrolments has no first stream semester.

CREATE OR REPLACE VIEW q6_filter_starting_day AS
SELECT pe.student, MIN(starting) as starting
FROM program_enrolments pe
JOIN semesters s 
ON pe.semester=s.id 
JOIN stream_enrolments se 
ON se.partof=pe.id 
JOIN streams st 
ON st.id=se.stream
GROUP BY pe.student;

CREATE OR REPLACE VIEW q6_first_stream AS
SELECT q.student,s.id as semester
FROM q6_filter_starting_day q
JOIN semesters s 
ON s.starting=q.starting; 

--2. The student’s average mark before their first stream semesters is greater than 75.

CREATE OR REPLACE VIEW q6_avg AS
SELECT ce.student
FROM q6_filter_starting_day qs 
JOIN course_enrolments ce 
ON ce.student=qs.student
JOIN courses c
ON c.id=ce.course
JOIN semesters se 
ON se.id=c.semester 
WHERE se.starting<qs.starting AND ce.mark IS NOT NULL
GROUP BY ce.student 
HAVING AVG(ce.mark)>75;


-- 3. The student is enrolled in at least one course for which the professor is a course lecturer.
 
CREATE OR REPLACE VIEW q6_ini_pair AS
SELECT DISTINCT ce.student, cs.staff
FROM q6_avg qv
JOIN course_enrolments ce
ON ce.student=qv.student
JOIN course_staff cs
ON cs.course=ce.course
JOIN staff_roles sr
ON sr.id=cs.role
WHERE sr.name='Course Lecturer';

--4. high-level	subjects, prof affiliation and result 
CREATE OR REPLACE VIEW Q6(student_unswid, professor_unswid, num_subjects) AS
SELECT ps.unswid as student_unswid, p.unswid as professor_unswid, COUNT(DISTINCT s.id) as num_subjects
FROM q6_ini_pair qp
JOIN affiliations a
ON a.staff=qp.staff AND a.isprimary=TRUE
JOIN course_enrolments ce
ON ce.student=qp.student
JOIN courses c
ON c.id=ce.course
JOIN subjects s
ON c.subject=s.id AND s.offeredby=a.orgunit
JOIN people as p 
ON qp.staff=p.id 
JOIN people as ps
ON qp.student=ps.id
WHERE substr(s.code, 5, 1) IN ('4', '5', '6', '7', '8', '9')
GROUP BY ps.unswid,p.unswid
HAVING COUNT(DISTINCT s.id)>5;

-- Q7:

--1. 2012 course has at least one staff record 

CREATE OR REPLACE VIEW q7_one_staff AS 
SELECT c.id as course, cs.staff, c.subject,c.semester,s.starting, s.ending, s.year   
FROM course_staff cs 
JOIN courses c 
ON c.id=cs.course 
JOIN semesters s 
ON s.id=c.semester
WHERE s.year = 2012 AND s.term IN ('S1', 'S2');

--2. new staff
CREATE OR REPLACE VIEW q7_new_staff AS 
SELECT DISTINCT qos.course, qos.staff
FROM q7_one_staff qos
WHERE NOT EXISTS (
    SELECT 1
    FROM course_staff cs2
    JOIN courses c2   ON c2.id = cs2.course
    JOIN semesters s2 ON s2.id = c2.semester
    WHERE cs2.staff   = qos.staff
      AND c2.subject  = qos.subject
      AND s2.starting < qos.starting
);

--3. half new staff 
CREATE OR REPLACE VIEW q7_result_staff AS 
SELECT qo.course
FROM q7_one_staff qo
LEFT JOIN q7_new_staff qn ON qn.course = qo.course AND qn.staff  = qo.staff
GROUP BY qo.course
HAVING 2 * COUNT(DISTINCT qn.staff) <= COUNT(DISTINCT qo.staff);

--4. avg condition 
CREATE OR REPLACE VIEW q7_course_subject_avg AS 
SELECT c.subject, ce.course, MAX(sm.starting) as starting, AVG(ce.mark) as avg_mark
FROM course_enrolments ce
JOIN courses c    
ON c.id = ce.course
JOIN semesters sm 
ON sm.id = c.semester
WHERE ce.mark IS NOT NULL
GROUP BY c.subject,ce.course;

CREATE OR REPLACE VIEW q7_most_recent AS
SELECT cur.course AS cur_course,    
       cur.avg_mark AS cur_avg, 
       prev.course   AS prev_course,
       prev.avg_mark AS prev_avg
FROM q7_course_subject_avg cur
JOIN q7_course_subject_avg prev
  ON prev.subject  = cur.subject
 AND prev.starting < cur.starting
WHERE NOT EXISTS (
    SELECT 1
    FROM q7_course_subject_avg mid
    WHERE mid.subject  = cur.subject
      AND mid.starting > prev.starting
      AND mid.starting < cur.starting
);

CREATE OR REPLACE VIEW q7_result_avg AS
SELECT qm.cur_course AS course
FROM q7_most_recent qm
WHERE qm.cur_course IN (SELECT course FROM q7_one_staff)
GROUP BY qm.cur_course, qm.cur_avg
HAVING qm.cur_avg > AVG(qm.prev_avg);


--5. student condition 
CREATE OR REPLACE VIEW q7_student_result AS
SELECT DISTINCT qo.course
FROM q7_one_staff qo
JOIN subjects sub
ON sub.id=qo.subject
JOIN course_enrolments ce1
ON ce1.course=qo.course
WHERE EXISTS (
  SELECT 1
  FROM course_enrolments ce
  JOIN courses c
  ON c.id=ce.course
  JOIN semesters s
  ON s.id=c.semester
  JOIN program_enrolments pe
  ON pe.student=ce.student AND pe.semester=c.semester
  JOIN programs p
  ON p.id=pe.program
  WHERE s.year<2012 AND ce.mark IS NOT NULL AND c.subject=qo.subject AND p.offeredby=sub.offeredby
);

--6. lecturer condtion 
CREATE OR REPLACE VIEW q7_lec_result AS
SELECT DISTINCT qo.course
FROM q7_one_staff qo
JOIN course_staff cs 
ON qo.course=cs.course 
JOIN staff_roles sr 
ON sr.id=cs.role 
JOIN subjects sub 
ON sub.id=qo.subject 
WHERE sr.name = 'Course Lecturer' 
AND EXISTS (
    SELECT 1
FROM course_staff cs1
JOIN staff_roles sr1 
ON sr1.id=cs1.role
JOIN courses c1 
ON c1.id=cs1.course 
JOIN semesters s1 
ON s1.id=c1.semester
JOIN subjects sub1 
ON sub1.id=c1.subject
WHERE sr1.name = 'Course Lecturer' AND qo.starting>s1.starting AND substr(sub.code, 1, 5) = substr(sub1.code, 1, 5) AND substr(sub.code, 1, 4) = substr(sub1.code, 1, 4) AND cs.staff=cs1.staff AND qo.course !=cs1.course
);

--7. result 
CREATE OR REPLACE VIEW Q7(course_id, num_students) AS
SELECT ce.course as course_id, COUNT (DISTINCT ce.student) as Num_students 
FROM (
  SELECT course FROM q7_lec_result qlr
  INTERSECT
  SELECT course FROM q7_result_avg qra
  INTERSECT
  SELECT course FROM q7_result_staff qrs
  INTERSECT
  SELECT course FROM q7_student_result qsr
) c
JOIN course_enrolments ce 
ON c.course=ce.course 
GROUP BY ce.course ;

-- Q8:
--1. filter student
CREATE OR REPLACE VIEW q8_students AS
SELECT st.id AS stream_id, st.code, st.name, pe.student, pe.program, pe.semester
FROM program_enrolments pe
JOIN stream_enrolments se
ON se.partof=pe.id
JOIN streams st
ON st.id=se.stream;

--2. filter marks 
CREATE OR REPLACE VIEW q8_marks AS
SELECT ce.student, c.semester, ce.mark
FROM course_enrolments ce
JOIN courses c
ON c.id=ce.course;

--3 function 
CREATE OR REPLACE FUNCTION Q8(program_code character(4), year integer, term character(2))
RETURNS SETOF text
AS $$
DECLARE
  p_id   integer;
  sem_id integer;
  r      record;
BEGIN
-- program id handling 
  SELECT MIN(p.id) INTO p_id
  FROM programs p
  WHERE p.code=Q8.program_code;

  IF p_id IS NULL THEN
    RETURN NEXT 'WARNING: Invalid Program Input';
    RETURN;
  END IF;

-- semester id handling 
  SELECT MIN(s.id) INTO sem_id
  FROM semesters s
  WHERE s.year=Q8.year AND s.term=Q8.term;

  IF sem_id IS NULL THEN
    RETURN NEXT 'WARNING: Invalid Term Input';
    RETURN;
  END IF;

-- core query 
  FOR r IN
    SELECT qs.code, qs.name,
           COUNT(DISTINCT qs.student) AS num_students,
           AVG(qm.mark) AS avg_mark
    FROM q8_students qs
    LEFT JOIN q8_marks qm
    ON qm.student=qs.student AND qm.semester=sem_id
    WHERE qs.program=p_id AND qs.semester=sem_id
    GROUP BY qs.stream_id, qs.code, qs.name
    ORDER BY num_students DESC, qs.code ASC
  LOOP
    RETURN NEXT r.code || ' | ' || r.name
             || ' | Students: ' || r.num_students
             || ' | Avg Mark: '
             || COALESCE(round(r.avg_mark::numeric, 2)::text, 'N/A');
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql;


-- Q9:
CREATE OR REPLACE FUNCTION Q9(unswid integer, year integer, term character(2)) 
RETURNS text AS $$
DECLARE
  stu_id integer;
  sem_id integer;
  pe_id integer;
  s_date date;
  uoc_total integer;
  passed_course integer;
  required_uoc integer;
  display_remained_uoc text;
  remained_course text;
  current_program char(4);
  remained_uoc integer;
  display_required text;
  program_id integer;

BEGIN

--check student id
  SELECT p.id INTO stu_id
  FROM people p
  WHERE p.unswid=Q9.unswid;

  IF stu_id IS NULL THEN
    RETURN 'WARNING: Invalid Student Input';
  END IF;

-- filter year, term 
  SELECT MIN(s.id) INTO sem_id
  FROM semesters s 
  WHERE Q9.year=s.year AND Q9.term=s.term;
  
  IF sem_id IS NULL THEN
    RETURN  'WARNING: Invalid Term Input';
  END IF;
    
-- filter student   
  SELECT MIN(pe.id) INTO pe_id
  FROM program_enrolments pe
  WHERE pe.student=stu_id AND pe.semester=sem_id;
  
  IF pe_id IS NULL THEN
    RETURN 'No program enrolment for term';
  END IF;

  SELECT p.code, pe.program INTO current_program, program_id
  FROM program_enrolments pe
  JOIN programs p 
  ON p.id=pe.program
  WHERE pe.id=pe_id;
  
-- Calculated UOC  
  SELECT s.starting INTO s_date
  FROM semesters s 
  WHERE s.id=sem_id;

  SELECT COALESCE(SUM(counting_pass.uoc), 0), COUNT(*) INTO uoc_total, passed_course
  FROM (
    SELECT DISTINCT c.subject, sub.uoc
    FROM course_enrolments ce
    JOIN courses c
    ON c.id=ce.course
    JOIN semesters s
    ON s.id=c.semester
    JOIN subjects sub
    ON sub.id=c.subject
    WHERE ce.student=stu_id AND s.starting<=s_date AND ce.mark>=50 AND EXISTS (
      SELECT 1
      FROM program_enrolments pe
      WHERE pe.student=ce.student AND pe.semester=c.semester AND pe.program=program_id
    )
  ) counting_pass;

 
 -- required UOC
  SELECT p.uoc INTO required_uoc
  FROM programs p
  WHERE program_id=p.id;

  IF required_uoc IS NULL THEN
      display_remained_uoc:='N/A';
      display_required:='N/A';
  ELSE 
      remained_uoc:=GREATEST(required_uoc - uoc_total, 0);
      display_remained_uoc:=remained_uoc::text;
      display_required:=required_uoc::text;

  END IF; 

  --course remaining
  IF remained_uoc IS NULL THEN 
    remained_course:='N/A';
  ELSEIF remained_uoc=0 THEN
    remained_course:='0';
  ELSE 
    remained_course:=ceil(remained_uoc/6.0)::integer::text;
  END IF;

RETURN current_program
  || ' | Required: ' || display_required
  || ' | Earned: ' || uoc_total
  || ' | Remaining: ' || display_remained_uoc
  || ' | Passed courses: ' || passed_course
  || ' | Courses remaining: ' || remained_course;

END;
$$ LANGUAGE plpgsql;

-- Q10:
CREATE OR REPLACE FUNCTION Q10(unswid integer) RETURNS SETOF text AS $$

DECLARE

num_ce integer; 
mean_mark numeric; 
display_mean_mark text;
people_id integer;
staff_id integer; 
staff_role_q10 integer;
sum_num_course integer;
sum_num_ce integer;
sum_mean_mark numeric;
r record; 
display_sum_mean_mark text;

BEGIN
  -- handle id 
  SELECT p.id INTO people_id
  FROM people p 
  WHERE Q10.unswid = p.unswid;

  SELECT p.id INTO staff_id
  FROM people p 
  JOIN staff s 
  ON s.id=p.id
  WHERE Q10.unswid = p.unswid;

  IF people_id IS NULL OR staff_id IS NULL THEN 
    RETURN NEXT 'WARNING: Invalid Staff Input';
    RETURN;
  END IF;

  SELECT cs.staff INTO staff_role_q10
  FROM course_staff cs
  WHERE cs.staff=staff_id;

-- org unit & number of courses
  FOR r IN 
    SELECT o.id as org_id, o.longname,COUNT(DISTINCT c.id) AS num_course
    FROM course_staff cs
    JOIN courses c 
    ON c.id=cs.course 
    JOIN subjects s 
    ON s.id=c.subject 
    JOIN orgunits o 
    ON o.id=s.offeredby 
    WHERE cs.staff=staff_role_q10
    GROUP BY o.id,o.longname

  LOOP
--course enroments & mark 
    SELECT COUNT(ce.mark),AVG(ce.mark) INTO num_ce, mean_mark
    FROM course_enrolments ce
    JOIN courses c
    ON c.id=ce.course
    JOIN subjects s
    ON s.id=c.subject
    WHERE s.offeredby=r.org_id
      AND EXISTS (
      SELECT 1
      FROM course_staff cs
      WHERE cs.course=c.id AND cs.staff=staff_role_q10
    );

    IF num_ce=0 THEN 
      display_mean_mark:='N/A';
    ELSE
      display_mean_mark:=round(mean_mark, 2)::text;
    END IF;

  RETURN NEXT r.longname || ' | Courses: ' || r.num_course
            || ' | Assessed: ' || num_ce
            || ' | Mean Mark: '
            || display_mean_mark;
  END LOOP;
--summery

  SELECT COUNT(DISTINCT c.id), COUNT(ce.mark), AVG(ce.mark)
  INTO sum_num_course, sum_num_ce, sum_mean_mark
  FROM courses c
  LEFT JOIN course_enrolments ce
  ON ce.course=c.id
  WHERE EXISTS (
    SELECT 1
    FROM course_staff cs
    WHERE cs.course=c.id AND cs.staff=staff_id
  );

  IF sum_num_ce=0 THEN 
    display_sum_mean_mark:='N/A';
  ELSE
    display_sum_mean_mark:=round(sum_mean_mark, 2)::text;
  END IF;
    
  RETURN NEXT '=== OVERALL' ||' | Courses: ' || sum_num_course
            || ' | Assessed: ' || sum_num_ce
            || ' | Mean Mark: '
            || display_sum_mean_mark  || ' ===';
  RETURN;
END;
$$ LANGUAGE plpgsql;
