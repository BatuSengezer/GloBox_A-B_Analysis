--joining all tables to one as a view keeping all activity
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

--joining all tables to one as a view summing spent and replacing null spent values with 0's for unique ids in activity
--DROP VIEW summed_spent_view;
CREATE OR REPLACE VIEW summed_spent_view AS
WITH sums AS(
SELECT  uid,
       SUM(ROUND(CAST(spent AS numeric),2)) sum_spent
FROM cleaned_activity
GROUP BY uid
)
SELECT  u.id, 
        g.device,
        COALESCE(s.sum_spent,0) sum_spent,
        g.group,
        g.join_dt,
        u.country,
        u.gender
FROM cleaned_groups g
JOIN cleaned_users u
ON g.uid = u.id
FULL JOIN  sums s
ON s.uid = u.id;

--checking summed_spent_view
SELECT * FROM summed_spent_view;

--checking num of rows
SELECT COUNT(*) FROM cleaned_activity;
SELECT COUNT(*) FROM cleaned_groups;
SELECT COUNT(*) FROM cleaned_users;
SELECT COUNT(DISTINCT uid) FROM cleaned_activity; -- duplicate uids
SELECT COUNT(*) FROM view;
SELECT COUNT(*) FROM summed_spent_view;

--checking distinct countries
SELECT DISTINCT country
FROM view;

--How many users in the control group were in Canada? 
SELECT COUNT(DISTINCT id)
FROM view 
WHERE   "group" = 'A' AND
        country = 'CAN';

--What was the conversion rate of all users? 
WITH user_counts AS (
  SELECT COUNT(DISTINCT id) total_users,
         COUNT(DISTINCT CASE WHEN spent > 0 THEN id END) converted_users
  FROM view
)
SELECT total_users, 
       converted_users,
       100*converted_users / CAST(total_users AS FLOAT) conversion_percentage
FROM user_counts;

--As of February 1st, 2023, how many users were in the A/B test? 
SELECT COUNT(DISTINCT id)
FROM view
WHERE join_dt <= '2023-02-01';
     
--What is the average amount spent per user for the control and treatment groups? 
SELECT  SUM(CASE WHEN "group" = 'A' THEN sum_spent END)/
        COUNT(CASE WHEN "group" = 'A' THEN id END) control_grp,
        SUM(CASE WHEN "group" = 'B' THEN sum_spent END)/
        COUNT(CASE WHEN "group" = 'B' THEN id END) treatment_grp
FROM summed_spent_view;

--What is the 95% confidence interval for the average amount spent per user in the control? (T-Value (two-tailed): +/- 1.960061)
--CI = X̄ ± t(α/2, n-1) * (s / √n)
WITH control_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS sample_standard_deviation,
        COUNT(id) sample_size      
FROM summed_spent_view
WHERE "group" = 'A'
)
SELECT  sample_size,
        sample_mean,
        sample_standard_deviation,
        sample_mean - (1.960061 * (sample_standard_deviation / SQRT(sample_size))) AS lower_bound,
        sample_mean + (1.960061 * (sample_standard_deviation / SQRT(sample_size))) AS upper_bound
FROM    control_group_stats;

--What is the 95% confidence interval for the average amount spent per user in the treatment? This question is required.*
WITH treatment_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS sample_standard_deviation,
        COUNT(id) sample_size      
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT  sample_size,
        sample_mean,
        sample_standard_deviation,
        sample_mean - (1.960061 * (sample_standard_deviation / SQRT(sample_size))) AS lower_bound,
        sample_mean + (1.960061 * (sample_standard_deviation / SQRT(sample_size))) AS upper_bound
FROM    treatment_group_stats;





