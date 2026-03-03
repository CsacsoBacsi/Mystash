select
   owner,
   object_type,
   object_name
from
   dba_objects
where
   status != 'VALID'
   and owner = 'AE_STG_AML'
--   and object_type = 'VIEW'
order by
   owner,
   object_type; 
