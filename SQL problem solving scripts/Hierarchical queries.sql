select a.CONS_DATE, a.MPAN_CORE, a.OVERLAY_VERSION
from hh_edf_cont_cons_olay a
group by a.CONS_DATE, a.MPAN_CORE, a.OVERLAY_VERSION
having count (*) > 1 ;

select /*+ materialize */
       to_date ('01/01/2008', 'DD/MM/YYYY') + level - 1 cal_date,
	   level
from
       dual   
connect by
       level <= to_date ('01/02/2008', 'DD/MM/YYYY') - to_date ('01/01/2008', 'DD/MM/YYYY')

select emp_id, man_id, name, level, sys_connect_by_path (name, '/') as path, connect_by_root name "Manager"
from	   
(select 1 as emp_id, 'A' as name, 10 as man_id from dual
union
select 10 as emp_id, 'AA' as name, 100 as man_id from dual
union
select 2 as emp_id, 'B' as name, 20 as man_id from dual
union
select 20 as emp_id, 'BB' as name, 100 as man_id from dual
union
select 3 as emp_id, 'C' as name, 20 as man_id from dual
union
select 100 as emp_id, 'TOTAL' as nam, 1000 as man_id from dual
union
select 1000 as emp_id, 'GRANDTOTAL' as nam, null as man_id from dual) a
start with emp_id = 1000
connect by nocycle prior emp_id = man_id
order siblings by name desc ;	    

select level
from dual 
connect by level = level ;