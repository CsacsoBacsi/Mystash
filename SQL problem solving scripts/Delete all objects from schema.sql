CREATE OR REPLACE PROCEDURE C10879.SP_DEL_ALL IS
-- To delete all objects from a specific schema

l_err_msg VARCHAR2 (3000) ; -- Error message

CURSOR C1 IS SELECT * 
               FROM (SELECT * 
                       FROM ALL_OBJECTS 
                      WHERE OWNER = 'C10879'
                            AND object_type in ('VIEW', 'TABLE')
                            AND object_name <> 'SP_DEL_ALL'
                            AND SUBSTR (OBJECT_NAME, 1, 4) <> 'BIN$'
                     UNION
                     SELECT * 
                       FROM ALL_OBJECTS 
                      WHERE owner = 'C10879'
                            AND object_type in ('SEQUENCE', 'PACKAGE')
                            AND object_name <> 'SP_DEL_ALL'
                            AND SUBSTR (OBJECT_NAME, 1, 4) <> 'BIN$')              
             ORDER BY object_type desc ;

CURSOR C2 IS SELECT * 
               FROM ALL_TYPES
              WHERE OWNER = 'C10879'
                    AND SUBSTR (TYPE_NAME, 1, 4) <> 'BIN$'
              ORDER BY typecode asc ;

BEGIN

-- Delete all objects except types
FOR c1_rec in c1 LOOP
   IF c1_rec.object_type = 'TABLE' THEN
       BEGIN
           EXECUTE IMMEDIATE 'DROP ' || c1_rec.object_type || ' ' || c1_rec.object_name || ' cascade constraints' ;

           EXCEPTION
           WHEN OTHERS THEN
               l_err_msg := SQLCODE || ' ' || SQLERRM ;
               dbms_output.put_line ('Could not delete ' || c1_rec.object_type || ': ' || c1_rec.object_name || '. Error: ' || l_err_msg) ;
       END ;
   ELSE
       BEGIN
           EXECUTE IMMEDIATE 'DROP ' || c1_rec.object_type || ' ' || c1_rec.object_name ;

           EXCEPTION
           WHEN OTHERS THEN
               l_err_msg := SQLCODE || ' ' || SQLERRM ;
               dbms_output.put_line ('Could not delete ' || c1_rec.object_type || ': ' || c1_rec.object_name || '. Error: ' || l_err_msg) ;
       END ;

   END IF ;
END LOOP ;    

-- Delete types starting with collections
FOR c2_rec in c2 LOOP
   BEGIN
       EXECUTE IMMEDIATE 'DROP TYPE ' || c2_rec.type_name ;
       
       EXCEPTION
       WHEN OTHERS THEN
           l_err_msg := SQLCODE || ' ' || SQLERRM ;
           dbms_output.put_line ('Could not delete ' || c2_rec.typecode || ' TYPE: ' || c2_rec.type_name) ;
   END ;
END LOOP ;    

    
EXCEPTION
    WHEN OTHERS THEN
        RAISE ;
END ;
/