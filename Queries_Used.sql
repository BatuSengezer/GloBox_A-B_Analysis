-- -- joining all tables to one as a view keeping all activity
-- DROP VIEW view;
-- CREATE OR REPLACE VIEW view AS
-- SELECT  u.id, 
--         a.dt purchase_dt, 
--         g.device,
--         ROUND(CAST(a.spent AS numeric),2) as spent,
--         g.group,
--         g.join_dt,
--         u.country,
--         u.gender
-- FROM cleaned_groups g
-- JOIN cleaned_users u
-- ON g.uid = u.id
-- FULL JOIN  cleaned_activity a
-- ON a.uid = u.id;

-- --checking view
--SELECT * FROM view;

-- --checking num of rows
-- SELECT COUNT(*) FROM cleaned_activity;
-- SELECT COUNT(*) FROM cleaned_groups;
-- SELECT COUNT(*) FROM cleaned_users;
-- SELECT COUNT(DISTINCT uid) FROM cleaned_activity; -- duplicate uids
-- SELECT COUNT(*) FROM view;

-- --checking distinct countries
-- SELECT DISTINCT country
-- FROM view;

-- --How many users in the control group were in Canada? 
-- SELECT COUNT(DISTINCT id)
-- FROM view 
-- WHERE   "group" = 'A' AND
--         country = 'CAN';

-- --What was the conversion rate of all users? 
-- WITH user_counts AS (
--   SELECT COUNT(DISTINCT id) total_users,
--          COUNT(DISTINCT CASE WHEN spent > 0 THEN id END) converted_users
--   FROM view
-- )
-- SELECT total_users, 
--        converted_users,
--        100*converted_users / CAST(total_users AS FLOAT) conversion_percentage
-- FROM user_counts;

-- --As of February 1st, 2023, how many users were in the A/B test? 
-- SELECT COUNT(DISTINCT id)
-- FROM view
-- WHERE join_dt <= '2023-02-01';
     
