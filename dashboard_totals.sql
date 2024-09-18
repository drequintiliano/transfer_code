CREATE OR REPLACE VIEW dashboard_totals AS
SELECT 
  -- Total Courses
  (SELECT COUNT(*) FROM activity WHERE active = TRUE and type::text = 'COURSE') AS total_courses  

  -- Total Alerts
  (SELECT COUNT(DISTINCT a.id) FROM alert a) AS total_alerts,

  -- Total Seen Alerts
  (SELECT COUNT(DISTINCT ea.*) FROM alert a RIGHT JOIN email_alert ea ON ea.id_alert = a.id) AS total_alerts_seen,
  
  -- Total Documents
  (SELECT COUNT(*) FROM document d WHERE NOT EXISTS (SELECT 1 FROM module_document md WHERE md.document_id = d.id)) AS total_documents,  

  -- Total Active Schools
  (SELECT COUNT(*) FROM school s WHERE s.active = TRUE) AS total_schools,

  -- Total User Logins
  (SELECT COUNT(ll.id_email) 
   FROM log_login ll 
   JOIN email e ON e.id = ll.id_email 
   JOIN email_school es ON es.id_email = e.id 
   WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE) AS total_logins,     

  -- Total Explored Items
  (SELECT COUNT(lur.logged_at) 
   FROM log_user_route lur 
   JOIN email e ON e.id = lur.id_email 
   WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE) AS total_explored_items,

  -- Total Users
  (SELECT COUNT(*) FROM "user" u  WHERE EXISTS (select e.id_user from email e WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE AND e.id_user = u.id)) AS total_users,

  -- Total Researches
  (SELECT COUNT(er.id_research) FROM email_research er 
   LEFT JOIN email e ON e.id = er.id_email 
   WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE) AS total_researches,

  -- Total Course Status
  (SELECT 
      SUM(subquery3.user_started) AS total_started,
      SUM(subquery3.user_not_started) AS total_not_started
    FROM (       
      SELECT   
          COUNT(DISTINCT subquery2.id_email) AS user_started,
          (SELECT COUNT(*) 
           FROM email_school es 
           JOIN email e ON e.id = es.id_email 
           WHERE es.id_school = s.id 
           AND e.active = TRUE 
           AND e.visible = TRUE 
           AND e.internal_user = FALSE) 
           - (COUNT(DISTINCT subquery2.id_email)) AS user_not_started
      FROM
          school s
      LEFT JOIN (
          SELECT
              id_email,
              jsonb_extract_path_text(school, 'id') AS id_school,
              unnest(started) AS course_started
          FROM (
              SELECT
                  v.id_email,
                  unnest(v.schools) AS school,
                  v.course_started AS started
              FROM v_user_course_status v
          ) AS subquery1
      ) AS subquery2 ON s.id = subquery2.id_school::int
      WHERE s.active = TRUE
      GROUP BY s.id
    ) AS subquery3
  ) AS total_course_status

