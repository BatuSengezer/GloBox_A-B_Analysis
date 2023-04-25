-- joining all tables to one
SELECT  a.uid, 
        a.dt, 
        a.device,
        a.spent,
        g.group,
        g.join_dt,
        u.country,
        u.gender
FROM activity a
JOIN groups g
ON a.uid = g.uid
JOIN users u
ON a.uid = u.id;

--checking for null values
SELECT  a.uid, 
        a.dt, 
        a.device,
        a.spent,
        g.group,
        g.join_dt,
        u.country,
        u.gender
FROM activity a
JOIN groups g
ON a.uid = g.uid
JOIN users u
ON a.uid = u.id
WHERE   a.uid IS NULL OR 
        a.dt IS NULL OR 
        a.device IS NULL OR 
        a.spent IS NULL OR 
        g.group IS NULL OR 
        g.join_dt IS NULL OR 
        u.country IS NULL OR 
        u.gender IS NULL;


--checking if there is error in devices column of activity and groups
SELECT  a.uid, 
        a.dt, 
        a.device,
        a.spent,
        g.group,
        g.join_dt,
        g.device,
        u.country,
        u.gender
FROM activity a
JOIN groups g
ON a.uid = g.uid
JOIN users u
ON a.uid = u.id;
