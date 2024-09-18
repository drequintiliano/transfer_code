CREATE OR REPLACE VIEW v_dashboard_totals AS
SELECT 
  (SELECT COUNT(*) FROM activity WHERE active = TRUE and type::text = 'COURSE') AS total_courses,
  (SELECT COUNT(DISTINCT a.id) FROM alert a) AS total_alerts,
  (SELECT COUNT(DISTINCT ea.*) FROM alert a RIGHT JOIN email_alert ea ON ea.id_alert = a.id) AS total_alerts_seen,
  (SELECT COUNT(*) FROM document d WHERE NOT EXISTS (SELECT 1 FROM module_document md WHERE md.document_id = d.id)) AS total_documents,  
  (select json_build_object(
      'totalDocsSeen', count(ld.id_email) filter (where ld."type"::text = 'view'),
      'totalDocsDownloaded', count(ld.id_email) filter (where ld."type"::text = 'download'),
      'totalDocsLinked', count(ld.id_email) filter (where ld."type"::text = 'link')
   ) as document_details_array 
    from log_document ld
    join email e on e.id = ld.id_email
    where e.active = true and e.internal_user = false and e.visible = true
    and NOT EXISTS (
      select 1 from module_document md where md.document_id = ld.id_document    
    )
    and EXISTS (
      select 1
      from email_school es
      join school s on s.id = es.id_school
      where s.active = true
      and es.id_email = ld.id_email
    )
  ) AS total_documents_details,  
  (select count (ll.id_email) 
   from log_login ll
   where EXISTS(
        select 1 from email e
        JOIN email_school es ON es.id_email = e.id
        WHERE  e.active = true
        AND e.visible = true
        AND e.internal_user = false
        AND ll.id_email = e.id
   )
  ) AS total_logins,     
  (SELECT COUNT(lur.logged_at) 
   FROM log_user_route lur 
   JOIN email e ON e.id = lur.id_email 
   WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE
  ) AS total_explored_items,
  (SELECT json_build_object(
    'total_started', SUM(subquery3.user_started),
    'total_not_started', SUM(subquery3.user_not_started)
    )
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
  ) AS total_course_status,
  (SELECT COUNT(*) FROM "user" u  WHERE EXISTS (select e.id_user from email e WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE AND e.id_user = u.id)) AS total_users,
  (SELECT COUNT(er.id_research) FROM email_research er 
   LEFT JOIN email e ON e.id = er.id_email 
   WHERE e.active = TRUE AND e.visible = TRUE AND e.internal_user = FALSE
  ) AS total_researches,
  (with all_courses as (
      select count(ar.activity_id)::float as total from activity_role ar 
      join email_role er on er.role_id = ar.role_id
      where er.email_id not in (
        select distinct e.id 
        from email e 
        where e.internal_user = false and e.visible = true and e.active = true
      )
      and er.role_id != 1
      and ar.activity_id not in (select distinct a.id from activity a where type::text = 'EVENT')
    ),
    completed_courses as (
      select (count(ec.course_id) filter (where ec.status::text = 'APPROVED'))::float as completed 
      from email_course ec
      where ec.email_id not in (
        select distinct e.id 
        from email e 
        where e.internal_user = false and e.visible = true and e.active = true
      )
    )
    select round(cast((completed * 100) / total as numeric), 2) as total_rate from completed_courses, all_courses
  ) AS total_rate_course,
  (SELECT COUNT(*) FROM school s WHERE s.active = TRUE) AS total_schools
;


CREATE INDEX idx_email_school_composite ON email_school (id_email, id_school);
CREATE INDEX idx_email_composite ON email (active, visible, internal_user);
CREATE INDEX idx_log_course_id_email ON log_course (id_email);
CREATE INDEX idx_activity_active_type ON activity (active, type);
CREATE INDEX idx_school_active ON school (active);

select * from dashboard_totals
