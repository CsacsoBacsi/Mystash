CREATE OR REPLACE procedure submit_cube_delete_job (p_aw_name varchar2, p_cube_name in varchar2) as
-- Purpose:        To delete a cube from a given AW using XML
-- Parameters      AWname, Cubename
-- Created by:     Csaba Riedlinger
-- Date:           15/10/2008
-- Change history: 
-- Note:           If for some reason this procedure stopped working, use the DELETE_CUBE ('CubeName') DML in the SYS.AWXML aw.

    xml_clob  clob;
    xml_clob2 clob ;
    xml_str   varchar2 (4000) ;
    ws        varchar2 (1000) ;

begin

    -- Test parameters
    if p_cube_name is null or p_aw_name is null then
        dbms_output.put_line ('ERROR: Invalid parameters.') ;
        return ;
    end if ;    

    -- Attach the AW first (system will attach it RW)
    dbms_lob.createtemporary (xml_clob, TRUE) ;
    dbms_lob.open (xml_clob, DBMS_LOB.LOB_READWRITE) ;
    dbms_lob.writeappend (xml_clob, 61, '  <!-- &lt;!DOCTYPE XMI SYSTEM &apos;Model.dtd&apos; &gt; -->') ;
    dbms_lob.writeappend (xml_clob, 64, '  <AWXML version = ''1.0'' timestamp = ''Mon Feb 11 13:29:11 2002''>') ;
    dbms_lob.writeappend (xml_clob, 17, '  <AWXML.content>') ;
    ws := '  <Attach Id="Action0" AWName="' || p_aw_name || '"></Attach>' ;
    dbms_lob.writeappend (xml_clob, 42 + length (p_aw_name), ws) ;
    dbms_lob.writeappend (xml_clob, 18, '  </AWXML.content>') ;    
    dbms_lob.writeappend (xml_clob, 10, '  </AWXML>') ;  
    dbms_lob.close (xml_clob) ;
    xml_str := sys.interactionExecute (xml_clob) ;
    if xml_str <> 'Success' then
        dbms_output.put_line ('ERROR: Could not attach AW ' || p_aw_name || ' in rw mode.') ;
        return ;
    end if ;
    dbms_output.put_line ('AW ' || p_aw_name || ' has been attached in rw mode.') ;

    -- Delete the cube 
    dbms_lob.createtemporary (xml_clob2, TRUE) ;
    dbms_lob.open (xml_clob2, DBMS_LOB.LOB_READWRITE) ;
    dbms_lob.writeappend (xml_clob2, 45, '  <!-- <!DOCTYPE XMI SYSTEM ''Model.dtd'' > -->') ;
    dbms_lob.writeappend (xml_clob2, 65, '  <AWXML version = ''1.0'' timestamp = ''Mon Feb 11 13:29:11 2002'' >') ;  
    dbms_lob.writeappend (xml_clob2, 17, '  <AWXML.content>') ;
    dbms_lob.writeappend (xml_clob2, 23, '  <Delete Id="Action1">') ;
    dbms_lob.writeappend (xml_clob2, 17, '  <ActiveObject >') ;
    ws := '  <Cube  Name="' || p_cube_name || '" Id="' || p_cube_name || '.CUBE">' ;
    dbms_lob.writeappend (xml_clob2, 28 + 2 * length (p_cube_name), ws) ;
    dbms_lob.writeappend (xml_clob2,  9, '  </Cube>') ; 
    dbms_lob.writeappend (xml_clob2, 17, '  </ActiveObject>') ;
    dbms_lob.writeappend (xml_clob2, 11, '  </Delete>') ;
    dbms_lob.writeappend (xml_clob2, 18, '  </AWXML.content>') ;
    dbms_lob.writeappend (xml_clob2, 10, '  </AWXML>') ;                   
    dbms_lob.close (xml_clob2) ;
    xml_str := dbms_aw_xml.execute (xml_clob2) ;  
    if xml_str <> 'Success' then
        dbms_output.put_line ('ERROR: Could not delete cube ' || p_cube_name || ' from aw.') ;
        return ;
    end if ;
    dbms_output.put_line ('Cube ' || p_cube_name || ' has been deleted from the aw.') ;    
    
    -- Commit the changes
    dbms_aw.aw_update ;
    commit ;
    dbms_output.put_line ('AW updated, committed.') ;    

    exception
    when OTHERS then
         dbms_output.put_line ('ERROR: ' || SQLCODE || ' ' || SQLERRM) ;
         rollback ;
         raise ;

  end;
/