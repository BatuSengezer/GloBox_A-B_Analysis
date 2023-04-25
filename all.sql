-- joining all tables to one as a view
--DROP VIEW view;
CREATE OR REPLACE VIEW view AS
SELECT  u.id, 
        a.dt purchase_dt, 
        g.device,
        ROUND(CAST(a.spent AS numeric),2) as spent,
        g.group,
        g.join_dt,
        u.country,
        u.gender
FROM cleaned_groups g
JOIN cleaned_users u
ON g.uid = u.id
FULL JOIN  cleaned_activity a
ON a.uid = u.id;

--checking view
SELECT * FROM view;

--checking tables
SELECT COUNT(*) FROM cleaned_activity;
SELECT COUNT(*) FROM cleaned_groups;
SELECT COUNT(*) FROM cleaned_users;


--checking num of rows
SELECT COUNT(*) FROM view;

--checking distinct countries
SELECT DISTINCT country
FROM view;

--How many users in the control group were in Canada? 
SELECT COUNT(*)
FROM view 
WHERE   "group" = 'A' AND
        country = 'CAN';
