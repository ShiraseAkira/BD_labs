-- Лаптев М.И. ПС-22
-- 1. Добавить внешние ключи.
ALTER TABLE lesson
ADD CONSTRAINT FK_lesson_teacher
	FOREIGN KEY (id_teacher)
	REFERENCES teacher (id_teacher),

	CONSTRAINT FK_lesson_subject
	FOREIGN KEY (id_subject)
	REFERENCES [subject] (id_subject),

	CONSTRAINT FK_lesson_group
	FOREIGN KEY (id_group)
	REFERENCES [group] (id_group);

ALTER TABLE student
ADD CONSTRAINT FK_student_group
	FOREIGN KEY (id_group)
	REFERENCES [group] (id_group);

ALTER TABLE mark
ADD CONSTRAINT FK_mark_lesson
	FOREIGN KEY (id_lesson)
	REFERENCES lesson (id_lesson),

	CONSTRAINT FK_mark_student
	FOREIGN KEY (id_student)
	REFERENCES student (id_student);
GO

-- 2. Выдать оценки студентов по информатике если они обучаются данному предмету.
--    Оформить выдачу данных с использованием view.
CREATE VIEW information_marks AS
SELECT st.name student, l.date, m.mark FROM lesson l
JOIN [subject] s ON l.id_subject = s.id_subject
JOIN student st ON st.id_group = l.id_group
JOIN mark m ON m.id_student = st.id_student AND m.id_lesson = l.id_lesson
WHERE s.name = 'Информатика'
GO

-- 3. Дать информацию о должниках с указанием фамилии студента и названия предмета.
--    Должниками считаются студенты, не имеющие оценки по предмету, который ведется в группе.
--    Оформить в виде процедуры, на входе идентификатор группы.
CREATE PROCEDURE student_with_debt @group_id INT
AS
SELECT st.name,  s.name FROM [group] g
JOIN student st ON st.id_group = g.id_group
JOIN lesson l ON l.id_group = g.id_group
JOIN [subject] s ON s.id_subject = l.id_subject
LEFT JOIN mark m ON m.id_lesson = l.id_lesson AND m.id_student = st.id_student

WHERE g.id_group = @group_id
group by st.name,  s.name
having COUNT(ALL m.mark) = 0
GO

EXEC student_with_debt @group_id = 1;
-- !Не понял, нужно ли было получать должников по всем группам с использованием этой процедуры

-- 4. Дать среднюю оценку студентов по каждому предмету для тех предметов, по которым 
--    занимается не менее 35 студентов.

--    !Не понятно, нужна ли средняя оценка СТУДЕНТА (студент - предмет - средняя оценка по этому предмету)
--     или ПРЕДМЕТА (предмет - средняя оценка по нему среди студентов)
--    !Если первое - какой будет средняя оценка, если оценок по предмету нет? NULL? 0? 2?
--    !Если второе, то также не понятно, как учитывать множество оценок студента
--     Прим.: studen1 имеет оценки [5,5,5,5], student2 - [3]
--     Следует ли считать средней оценку (а) '4.6' === AVG(5,5,5,5,3)
--     или оценку (б)'4' === AVG(AVG(5,5,5,5),AVG(3))
--    Выполнил по парианту 2а, как на мой взгляд наиболее простому
WITH sw35st AS (
SELECT s.id_subject, s.name
FROM (
	SELECT st.id_group, COUNT(*) stundent_count FROM student st
	GROUP BY st.id_group) stq
	JOIN 
	(SELECT DISTINCT l.id_group, l.id_subject FROM lesson l) ss 
	ON stq.id_group = ss.id_group
	JOIN [subject] s
	ON ss.id_subject = s.id_subject
GROUP BY s.id_subject, s.name
HAVING SUM(stundent_count) >= 35)

SELECT sw35st.name, ROUND(AVG(CAST(mark AS FLOAT)), 2) average_mark FROM sw35st
JOIN lesson l ON sw35st.id_subject = l.id_subject
JOIN mark m ON m.id_lesson = l.id_lesson
GROUP BY sw35st.name

-- 5. Дать оценки студентов специальности ВМ по всем проводимым предметам с указанием группы,
--    фамилии, предмета, даты. При отсутствии оценки заполнить значениями NULL поля оценки.
SELECT g.name 'group', st.name student, s.name subject, l.date, mark FROM [group] g
JOIN student st ON st.id_group = g.id_group
JOIN lesson l ON l.id_group = g.id_group
JOIN [subject] s ON s.id_subject = l.id_subject
LEFT JOIN mark m ON m.id_student = st.id_student AND m.id_lesson = l.id_lesson

WHERE g.name = 'ВМ'
--ORDER BY student, 'subject', date
ORDER BY 'subject', date, student

-- 6. Всем студентам специальности ПС, получившим оценки меньшие 5 по предмету
--    БД до 12.05, повысить эти оценки на 1 балл.
UPDATE mark 
SET mark = mark + 1
WHERE id_mark IN (
	SELECT m.id_mark FROM [group] g
	JOIN student st ON g.id_group = st.id_group
	JOIN lesson l ON l.id_group = g.id_group
	JOIN [subject] s ON s.id_subject = l.id_subject
	JOIN mark m ON m.id_student = st.id_student AND m.id_lesson = l.id_lesson
	WHERE g.name = 'ПС' AND s.name = 'БД' AND mark < 5 AND l.date < '12/05/2019')

-- 7. Добавить необходимые индексы.