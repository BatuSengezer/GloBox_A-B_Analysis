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
SELECT  SUM(sum_spent) / COUNT(id) control_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS control_std_dev,
        COUNT(id) control_sample_size      
FROM summed_spent_view
WHERE "group" = 'A'
)
SELECT  control_sample_size,
        control_sample_mean,
        control_std_dev,
        control_sample_mean - (1.960061 * (control_std_dev / SQRT(control_sample_size))) AS lower_bound,
        control_sample_mean + (1.960061 * (control_std_dev / SQRT(control_sample_size))) AS upper_bound
FROM    control_group_stats;

--What is the 95% confidence interval for the average amount spent per user in the treatment?
WITH treatment_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) treatment_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS treatment_std_dev,
        COUNT(id) treatment_sample_size      
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT  treatment_sample_size,
        treatment_sample_mean,
        treatment_std_dev,
        treatment_sample_mean - (1.960061 * (treatment_std_dev / SQRT(treatment_sample_size))) AS lower_bound,
        treatment_sample_mean + (1.960061 * (treatment_std_dev / SQRT(treatment_sample_size))) AS upper_bound
FROM    treatment_group_stats;

--Conduct a hypothesis test to see whether there is a difference in the average amount spent per user between the two groups. 
--What are the resulting p-value and conclusion? Use the t distribution and a 5% significance level. Assume unequal variance.

--Null Hypothesis(H0): There is no difference in the average amount spent per user between the two groups.
--Alternative Hypothesis(HA): There is a difference in the average amount spent per user between the two groups.
WITH control_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) control_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS control_std_dev,
        COUNT(id) control_sample_size      
FROM summed_spent_view
WHERE "group" = 'A'
),
treatment_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) treatment_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS treatment_std_dev,
        COUNT(id) treatment_sample_size      
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT  0.05 AS significance_level,
        SQRT((control_std_dev^2/control_sample_size) + (treatment_std_dev^2/treatment_sample_size)) AS standard_error_of_diff,
        ABS((control_sample_mean - treatment_sample_mean)/SQRT((control_std_dev^2/control_sample_size) + (treatment_std_dev^2/treatment_sample_size))) AS t_statistic,
        (control_sample_size-1)+(treatment_sample_size-1) AS degrees_of_freedom,
        0.944 AS p_value
FROM control_group_stats
CROSS JOIN treatment_group_stats;
--p value calculated with excel.
--It can be concluded that p value is higher then significance level thus fail to reject null hypothesis. 
--There is not enough evidence to suggest a significant difference in the mean amount spent per user between the control and treatment groups


--What is the 95% confidence interval for the difference in the average amount spent per user 
--between the treatment and the control (treatment-control)?
WITH control_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) control_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS control_std_dev,
        COUNT(id) control_sample_size      
FROM summed_spent_view
WHERE "group" = 'A'
),
treatment_group_stats AS(
SELECT  SUM(sum_spent) / COUNT(id) treatment_sample_mean,
        STDDEV_SAMP(pg_catalog.NUMERIC(sum_spent)) AS treatment_std_dev,
        COUNT(id) treatment_sample_size      
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT 
    treatment_sample_mean - control_sample_mean AS mean_diff,
    treatment_sample_mean - control_sample_mean - (treatment_std_dev^2/treatment_sample_size + control_std_dev^2/control_sample_size)^0.5 * 1.96 AS lower_bound,
    treatment_sample_mean - control_sample_mean + (treatment_std_dev^2/treatment_sample_size + control_std_dev^2/control_sample_size)^0.5 * 1.96 AS upper_bound
FROM control_group_stats
CROSS JOIN treatment_group_stats;

--What is the user conversion rate for the control and treatment groups?
WITH control_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END) control_conv_cnt,
        COUNT(id) control_sample_size      
FROM summed_spent_view
WHERE "group" = 'A'
),
treatment_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END) AS treatment_conv_cnt,
        COUNT(id) treatment_sample_size      
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT  *,
        100 * control_conv_cnt::FLOAT / control_sample_size AS control_conversion_percent,
        100 * treatment_conv_cnt::FLOAT / treatment_sample_size AS treatment_conversion_percent
FROM control_group_stats
CROSS JOIN treatment_group_stats;

--What is the 95% confidence interval for the conversion rate of users in the control? Using normal distribution
--z_score is 1.960061
WITH control_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END) control_conv_cnt,
        COUNT(id) control_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS control_conversion_rate,
        SQRT(COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) * (1 - COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id)) / COUNT(id)) AS standard_error,
        1.960061 AS z_score
FROM summed_spent_view
WHERE "group" = 'A'
)
SELECT  control_conversion_rate - z_score * standard_error AS lower_bound,
        control_conversion_rate + z_score * standard_error AS upper_bound
FROM control_group_stats;

--What is the 95% confidence interval for the conversion rate of users in the treatment?
--z_score is 1.960061
WITH treatment_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END) treatment_conv_cnt,
        COUNT(id) treatment_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS treatment_conversion_rate,
        SQRT(COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) * (1 - COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id)) / COUNT(id)) AS standard_error,
        1.960061 AS z_score
FROM summed_spent_view
WHERE "group" = 'B'
)
SELECT  treatment_conversion_rate - z_score * standard_error AS lower_bound,
        treatment_conversion_rate + z_score * standard_error AS upper_bound
FROM treatment_group_stats;

--Conduct a hypothesis test to see whether there is a difference in the conversion rate between the two groups. 
--What are the resulting p-value and conclusion?
--Use the normal distribution and a 5% significance level. Use the pooled proportion for the standard error

--Null Hypothesis(H0): There is no difference in the conversion rate between the two groups.
--Alternative Hypothesis(HA): There is a difference in the conversion rate between the two groups.
WITH control_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT control_conv_cnt,
        COUNT(id)::FLOAT control_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS control_conversion_rate
FROM summed_spent_view
WHERE "group" = 'A'
),
treatment_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT treatment_conv_cnt,
        COUNT(id)::FLOAT treatment_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS treatment_conversion_rate
FROM summed_spent_view
WHERE "group" = 'B'
),
hypothesis_stats AS(
SELECT  control_sample_size,
        treatment_sample_size,
        control_conversion_rate,
        treatment_conversion_rate,
        (control_conv_cnt + treatment_conv_cnt) / (control_sample_size+ treatment_sample_size) AS pooled_proportion
FROM    control_group_stats
CROSS JOIN treatment_group_stats
)
SELECT  pooled_proportion,
        SQRT(pooled_proportion * (1 - pooled_proportion) * (1/control_sample_size + 1/treatment_sample_size)) AS standard_error,
        (treatment_conversion_rate - control_conversion_rate) / 
        SQRT(pooled_proportion * (1 - pooled_proportion) * (1/control_sample_size + 1/treatment_sample_size)) AS z_value,
        0.000111412 AS p_value
FROM hypothesis_stats;
--p value calculated with excel.
--It can be concluded that p value is lower then significance level thus reject null hypothesis. 
--There is statically significant difference in the conversion rate between the control and treatment groups


--What is the 95% confidence interval for the difference in the conversion rate between the treatment and control (treatment-control)?
--z_score is 1.960061
WITH control_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT control_conv_cnt,
        COUNT(id)::FLOAT control_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS control_conversion_rate
FROM summed_spent_view
WHERE "group" = 'A'
),
treatment_group_stats AS(
SELECT  COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT treatment_conv_cnt,
        COUNT(id)::FLOAT treatment_sample_size,
        COUNT(CASE WHEN sum_spent > 0 THEN id END)::FLOAT / COUNT(id) AS treatment_conversion_rate
FROM summed_spent_view
WHERE "group" = 'B'
),
hypothesis_stats AS(
SELECT  control_sample_size,
        treatment_sample_size,
        control_conversion_rate,
        treatment_conversion_rate,
        SQRT((control_conversion_rate * (1 - control_conversion_rate) / control_sample_size) 
        + (treatment_conversion_rate * (1 - treatment_conversion_rate) / treatment_sample_size)) AS se_diff
FROM control_group_stats
CROSS JOIN treatment_group_stats
)
SELECT  treatment_conversion_rate - control_conversion_rate AS conv_rate_diff,
        (treatment_conversion_rate - control_conversion_rate) - (1.96 * se_diff) AS lower_bound,
        (treatment_conversion_rate - control_conversion_rate) + (1.96* se_diff) AS upper_bound
FROM hypothesis_stats;


