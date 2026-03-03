CREATE OR REPLACE PACKAGE BODY EDF_NHH.PKG_EDF_NHH_LOAD_CUBE AS
/******************************************************************************
   NAME:       PKG_EDF_NHH_LOAD_CUBE
   PURPOSE:    Package follows on from relational processeing of demand forecast data.
               Once the deta is ready, this code creates a cube per version,
               loads the data into the cube.
               if a gsp_bmu paramter is supplied it automatically creates a scenario
               which leads to the final task of create ew view

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        03/09/2008            P8857 Created this package.
******************************************************************************/

 gv_version_id VARCHAR2(100);
 gv_gsp_bmu_id VARCHAR2(100);
 gv_short_version_id VARCHAR2(100);
 gv_sc_id VARCHAR2(100):=NULL;
 aw_name VARCHAR2(100):='EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT';
 gv_attach BOOLEAN:=false;
 gv_sc_task_id NUMBER(5);

 function get_xml_load_id return number as
 lv_xml_load_id number(5);
 begin
    with data1 as(
        select xml_loadid--max(xml_loadid)
        from olapsys.xml_load_log ll
        where ll.XML_MESSAGE like '%Started Build(Refresh) of EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT Analytic Workspace%'
     --   and XML_AW='SYS.AWXML'
    intersect

        select xml_loadid--max(xml_loadid)
        from olapsys.xml_load_log ll
        where ll.XML_MESSAGE like '%Starting Parallel Processing.%')
    select max(xml_loadid)
    into lv_xml_load_id
    from data1
    order by xml_loadid desc;
    dbms_output.put_line('watching load id:'||lv_xml_load_id);
    return lv_xml_load_id;
 end;


 procedure watch_maintain( p_long_ver_id in VARCHAR2) as
    lv_xml_err number;
    lv_xml_complete number;
    lv_xml_load_id number;
    /*
    *
    * procedure added to loop until the load in parelle is complete, task manager will execute this so other tasks
    * can be triggered on completion i.e. set display flag, create sc & create ew
    *
    */
 begin
    lv_xml_err:=0;
    lv_xml_complete:=0;
    lv_xml_load_id:= get_xml_load_id();
    update edf_nhh.EDF_NHH_OUTPUT_VER_DIM set XML_LOAD_ID=lv_xml_load_id where SCENARIO_ID=p_long_ver_id;
    commit;
    -- now i have the load id, i will keep looping until i have an error or a completed build of work space
    dbms_output.put_line('Loop Started');
     while (lv_xml_complete=0 AND  lv_xml_err=0) loop
            select count(*)
            into lv_xml_complete
            from olapsys.xml_load_log
            where xml_message like '%Completed Build(Refresh) of EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT Analytic Workspace.%'
            and xml_loadid = lv_xml_load_id;

            select count(*)
            into lv_xml_err
            from olapsys.xml_load_log
            where xml_message like '%**Error Occured%'
            and xml_loadid = lv_xml_load_id;
            --sleep for 15 minutes
            DBMS_LOCK.sleep(300);
            dbms_output.put_line('Waiting...');
        end loop;
        dbms_output.put_line('Loop Ended');
        dbms_output.put_line('lv_xml_complete:'||lv_xml_complete);
        dbms_output.put_line('lv_xml_err:'||lv_xml_err);
        dbms_aw.execute('aw attach edf_nhh_output_aw.edf_nhh_output rw');
        -- end of watch
 end;

 procedure create_cube(p_short_version_id in varchar2,p_attach boolean )as
    xml_clob clob;
    xml_result varchar2(4000);
    v_err_txt varchar2(4000);
    tmp             genwstringsequence;
 begin
    dbms_output.put_line('create cube per version');
        begin
            if (p_attach) then
              --  dbms_aw.aw_detach(aw_name);
                dbms_aw.execute('aw attach '||aw_name||' rw');
            end if;
            select replace(job_xml,'**VERSION_ID**',p_short_version_id)
            into xml_clob
            from   xml_maintenance_jobs
            where JOB_NAME='CRE_EDF_NHH_DF_CUBE';
            tmp := dbms_aw_xml.readawmetadata(aw_name,'RW');
          --  dbms_output.put_line('debug:'||xml_clob);
        -- sp_log_progress(p_job_id, v_sub_id, 'sp_create_cube_per_version', 'Create Cube XML Generated');
             xml_result :=  dbms_aw_xml.execute(xml_clob); --sys.interactionExecute(xml_clob);
             dbms_output.put_line('CUBE CREATED');
         --sp_log_progress(p_job_id, v_sub_id, 'sp_create_cube_per_version', 'Create Cube from XML done');
        exception when others
        then
            v_err_txt := dbms_lob.substr(xml_clob, 4000, 1);
            dbms_output.put_line('v_err_txt:'||v_err_txt);
            --sp_log_progress(p_job_id, v_sub_id, 'sp_create_cube_per_version', SQLCODE || ' - ' || SQLERRM || ' **ERROR** Creating Cube Per Version from XML:'||v_err_txt);
        end;

        tmp := dbms_aw_xml.readawmetadata(aw_name,'RW');

        if (p_attach) then
            dbms_aw.execute('aw detach '||aw_name);
        end if;
  end;

  procedure submit_job(p_short_version_id in varchar2, p_long_version_id in varchar2) as
    xml_clob clob;
    xml_str varchar2(4000);
    isAW number;
  begin
        delete from EDF_NHH_LATEST_LOADED_VER;
        insert into EDF_NHH_LATEST_LOADED_VER values (p_long_version_id);
        COMMIT;
        dbms_aw.execute('aw detach edf_nhh_output_aw.edf_nhh_output');
        DBMS_LOB.CREATETEMPORARY(xml_clob,TRUE);
        dbms_lob.open(xml_clob, DBMS_LOB.LOB_READWRITE);
        dbms_lob.writeappend(xml_clob, 200 ,'  <BuildDatabase  Id="Action16" AWName="EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT" BuildType="BACKGROUND" RunSolve="true" CleanMeasures="false" CleanAttrs="false" CleanDim="false" TrackStatus="true" MaxJobQueu');
        dbms_lob.writeappend(xml_clob, 7, 'es="8">');
        dbms_lob.writeappend(xml_clob, (48+length(p_short_version_id)-3), '    <BuildList XMLIDref="NHH_OUTPUT_'||p_short_version_id||'.CUBE" />');
        dbms_lob.writeappend(xml_clob, 18, '  </BuildDatabase>');
        dbms_lob.close(xml_clob);
        xml_str := dbms_aw_xml.execute(xml_clob); --sys.interactionExecute(xml_clob);
        dbms_output.put_line(xml_str);
        -- give its 2 minutes for the Start of Build AW
        DBMS_LOCK.sleep(120);
  end;

  FUNCTION create_sc(p_version_id in varchar2,p_sc_id out varchar2,p_maintain_ver_task_id in number) RETURN NUMBER as
    task_name VARCHAR2(100);
    task_id NUMBER(5);
  begin
     dbms_output.put_line('create blank scenario based on version');
    -- select NHH_OUTPUT_SC_SEQ.nextval into gv_sc_id from dual;
     gv_sc_id :='EW'||gv_short_version_id;
     task_name:='EW Step 1: Create EDF DF SC  '||gv_sc_id;
     pkg_task_manager.createtask(aw_name ,task_name,task_id);
     if (p_maintain_ver_task_id is not null) then
        FINANCE.PKG_TASK_MANAGER.SET_DEPENDSON(task_id,p_maintain_ver_task_id);
     end if;

     PKG_TASK_MANAGER.ADDSTEP_ADD_SCENARIO(task_id,'NHH_OUTPUT_SC',gv_sc_id);

     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'LIMIT NHH_OUTPUT_VER TO '''||p_version_id||'''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'LIMIT NHH_OUTPUT_SC TO '''||gv_sc_id||'''','xx','xx');

     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_USER_COMMENT = ''com''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_CRE_DATE = today','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_PARENT_ID = '''||p_version_id||'''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_SHORT_DESCRIPTION = ''sd''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_LONG_DESCRIPTION = ''ld''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC.NHH_OUTPUT_VER (NHH_OUTPUT_SC '''||gv_sc_id||''')  = '''||p_version_id||'''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_PUBLISHED = ''Y''','xx','xx');

     pkg_task_manager.AddStep_AWCommit(task_id);
     pkg_task_manager.enqueuetask(task_id);

     p_sc_id := gv_sc_id;

     RETURN task_id;
  end;

  procedure create_ew(sc_id varchar2,p_gsp_id varchar2, p_sc_task_id in number) as
    date1 varchar2(100);
    date2 varchar2(100);
    task_name VARCHAR2(100);
    task_id NUMBER(5);
  begin
     dbms_output.put_line('create energy wholesale view');
     dbms_output.put_line('using gsp bmu '||p_gsp_id);
     task_name:='EW Step 2: Create EW  '||sc_id;

     select to_char(forecast_start_date,'DDMONYY'), to_char(forecast_end_date,'DDMONYY')
     into date1, date2
     from VW_EDF_NHH_OUTPUT_VER_DIM
     where SCENARIO_ID = gv_version_id;

     pkg_task_manager.createtask(aw_name ,task_name,task_id);

     if (p_sc_task_id is not null) then
        FINANCE.PKG_TASK_MANAGER.SET_DEPENDSON(task_id,p_sc_task_id);
     end if;

     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_energy_wholesale_pub(NHH_OUTPUT_SC '''||sc_id||''') =''X''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_PUBLISHED(NHH_OUTPUT_SC '''||sc_id||''') =''Y''','xx','xx');
     pkg_task_manager.AddStep_AWCommit(task_id);

     PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'begin SP_PUBLISH_EDF_NHH_OUTPUT ('''||sc_id||'''); end;');
     PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'begin pkg_edf_nhh_pub.set_param('''||sc_id||''', '''||p_gsp_id||''' ,  to_date('''||date1||''',''ddmmyy'') ,  to_date('''||date2||''',''ddmmyy'')); end;');
     pkg_task_manager.add_xml_generic_task_step(task_id,aw_name,'CUBE','ENERGY_WHOLESALE',null);
     PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'begin edf_nhh_m_ew_pub.post_process(''COMPLETED''); END;');

     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_GSP_BMU_SC(NHH_OUTPUT_SC '''||sc_id||''') ='''||p_gsp_id||'','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_PUBLISHED(NHH_OUTPUT_SC '''||sc_id||''') =''Y''','xx','xx');
     PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'NHH_OUTPUT_SC_energy_wholesale_pub(NHH_OUTPUT_SC '''||sc_id||''') =''Y''','xx','xx');

	 pkg_task_manager.AddStep_AWCommit(task_id);
     PKG_TASK_MANAGER.SET_DEPENDSON(task_id,p_sc_task_id);
     pkg_task_manager.enqueuetask(task_id);
  end;

  procedure set_display_flag(p_version_id in varchar2) as
  begin
    dbms_output.put_line('set display flag');
  end;

  procedure task_processor(lv_create_exists IN BOOLEAN) IS
    lv_xml_load_id NUMBER(5);
    lv_sc_id VARCHAR2(100);
    task_name varchar2(200);
    task_id int;
  begin

        task_name:='Cube Create & Load Processor '||gv_version_id;
        pkg_task_manager.createtask(aw_name ,task_name,task_id);

        if (lv_create_exists = false) THEN
            dbms_output.put_line('cube does not exists');
           -- create_cube(gv_short_version_id);
            PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,
                'declare begin PKG_EDF_NHH_LOAD_CUBE.create_cube('''||gv_short_version_id||''',false); end;');
        ELSE
            dbms_output.put_line('cube does exists');
        END IF;
        PKG_TASK_MANAGER.add_xml_generic_task_step(task_id,aw_name,'DIMENSION','NHH_OUTPUT_VER',null);

        PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,
                'declare begin PKG_EDF_NHH_LOAD_CUBE.submit_job('''||gv_short_version_id||''','''||gv_version_id||'''); end;');

       -- submit_job(gv_short_version_id);

        PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,
                'declare begin PKG_EDF_NHH_LOAD_CUBE.watch_maintain('''||gv_version_id||'''); end;');
        --watch_maintain(gv_version_id);

        PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,
                'declare begin PKG_EDF_NHH_LOAD_CUBE.set_display_flag('''||gv_version_id||'''); end;');
        --set_display_flag(gv_version_id);


        pkg_task_manager.AddStep_AWCommit(task_id);
        pkg_task_manager.enqueuetask(task_id);

      /* the task to create cube per version and do load is done, now create a sc and ew.*/

        if (gv_gsp_bmu_id is not null) then
            gv_sc_task_id := create_sc(gv_version_id,lv_sc_id,task_id);
            create_ew(lv_sc_id,gv_gsp_bmu_id,gv_sc_task_id);
        else
            dbms_output.put_line('ew view not required');
        end if;
  end;




  PROCEDURE do_main(p_version_id IN VARCHAR2, p_gsp_bmu_id IN VARCHAR2,p_attach boolean default false) AS
    cube_exists boolean := false;
    lv_cmd VARCHAR2(100);
    output VARCHAR2(4000);
  BEGIN
    gv_version_id := p_version_id;
    gv_gsp_bmu_id := p_gsp_bmu_id;
    gv_attach := p_attach;

    begin
        SELECT NHH_EDF_VER
        INTO gv_short_version_id
        from EDF_NHH_OUTPUT_VER_DIM
        where SCENARIO_ID = p_version_id;
    exception when others then
        raise_application_error(-20100,'Version '||p_version_id||' does not exist');
    end;


    dbms_output.put_line('Engine Version 1.0');
    dbms_output.put_line('gv_version_id:'||gv_version_id);
    dbms_output.put_line('gv_gsp_bmu_id'||gv_gsp_bmu_id);


  --  if (gv_attach) then
       -- dbms_aw.aw_detach(aw_name);
    dbms_aw.execute('aw attach '||aw_name||' ro');
    --end if;
  --  --lv_cmd := 'shw ISVALUE (ALL_CUBES  ''NHH_OUTPUT_'||p_version_id||'.CUBE'')';
    lv_cmd := 'shw exists(''NHH_OUTPUT_'||gv_short_version_id||''')';
    DBMS_AW.run(lv_cmd,output);
 --   if (gv_attach) then
        dbms_aw.execute('aw detach '||aw_name);
 --   end if;

    dbms_output.put_line('Cube Exists..'||output);
    if (output like '%no%') THEN
        cube_exists := FALSE;
    END IF;
    if (output like '%yes%') THEN
        cube_exists := TRUE;
    END IF;

    task_processor(cube_exists);
  END;


END PKG_EDF_NHH_LOAD_CUBE;
/