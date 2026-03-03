select /*+ INDEX_COMBINE (e idx_emp_id idx_mgr_id) */ * -- Converts rowids to bitmap
  FROM emp e
  WHERE dept_id = 108 -- Must be equality
     OR mgr_id = 110 ; -- Must be equality

select /*+ INDEX_JOIN (e idx_emp_id idx_mgr_id) */ * --Concats resultsets from index scans
  FROM emp e
  WHERE emp_id = 108
     OR mgr_id = 110 ;
	 
select /*+ USE_CONCAT */ * -- Same as previous
  FROM emp e
  WHERE dept_id < 108
     OR mgr_id < 110 ;
	 
select /*+ NO_EXPAND */ * -- Does not expands query into two (because of OR condition) then concats it
  FROM emp e
  WHERE dept_id = 108
     OR mgr_id = 110 ;
	 
SELECT /*+ MERGE (t2) */ t1.*, t2.avg_sal -- Joins the two tables together than GROUP BYs and filters 
FROM   emp t1, 
       (SELECT dept_id, avg (sal) as avg_sal  
       FROM emp t2 
       GROUP BY dept_id) t2 
  WHERE t1.dept_id = t2.dept_id 
        AND t1.sal > t2.avg_sal ; 

SELECT /*+ NO_MERGE */ t1.*, t2.avg_sal -- GROUP BYs (view), sorts and filters first then joins the tables together 
FROM   emp t1, 
       (SELECT dept_id, avg (sal) as avg_sal  
       FROM emp t2 
       GROUP BY dept_id) t2 
  WHERE t1.dept_id = t2.dept_id 
        AND t1.sal > t2.avg_sal ; 

SELECT /*+ NO_UNNEST */ t1.*   
FROM   emp t1 
WHERE  emp_id IN (SELECT /*+ NO_UNNEST */ emp_id  
                    FROM emp t2
					where sal > 1000
                    ) ;

SELECT /*+ */ t1.*   
FROM   emp t1 
WHERE  emp_id IN ((SELECT /*+ UNNEST */ 1 FROM DUAL -- Uses the unioned resultset to loop over (NL), then index access EMP
              UNION ALL 
			  SELECT /*+ UNNEST */ 2 FROM DUAL)) ;

SELECT /*+ */ t1.*   
FROM   emp t1 
WHERE  emp_id IN ((SELECT /*+ NO_UNNEST */ 1 FROM DUAL -- Uses each EMP_ID to check for existence in UNION DUAL
              UNION ALL 
			  SELECT /*+ NO_UNNEST */ 2 FROM DUAL)) ;
					
