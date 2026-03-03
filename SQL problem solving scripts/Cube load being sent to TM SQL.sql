CREATE OR REPLACE package EDF_NHH.ECNS_CUBE_LOAD_CR56 as

PROCEDURE do_load(sc_id varchar2,dependsOn NUMBER);
PROCEDURE update_load(p_load_id number, message varchar2);

end;
/

CREATE OR REPLACE package body EDF_NHH.ECNS_CUBE_LOAD_CR56 as

    procedure create_task(sc_id varchar2, load_id number, dependsOn number) as
         task_id int;
         aw_name varchar2(50);
         task_name varchar2(200);
         header1  varchar2(200);
         upd_stmt varchar2(200);
         job_xml varchar2 (4000) ;         
    begin
         aw_name:='EDF_NHH_ECNS_AW.ECNS';
         task_name:='ECNS Cube Load - SC ID:'||sc_id;
         pkg_task_manager.createtask(aw_name ,task_name,task_id,'BATCH');
         upd_stmt:='declare begin ECNS_CUBE_LOAD_CR56.update_load('||load_id||',''XML LOAD STARTED''); end;';
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,upd_stmt);

         upd_stmt:=' update ECNS_SC_DISPLAY_DIM set display=''N'' where sc ='''||sc_id||''' ';
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,upd_stmt);
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'commit');

         pkg_task_manager.add_xml_generic_task_step(task_id,aw_name,'DIMENSION','ECNS_SC',null);
         pkg_task_manager.AddStep_AWCommit(task_id);

         -- 09/10/2008 CR: Trackstatus is set to true for performance reasons and the xml is constructed then passed to procedure
         job_xml := '<BuildDatabase  Id="Action5" AWName="EDF_NHH_ECNS_AW.ECNS" BuildType="EXECUTE" RunSolve="true" CleanMeasures="false" CleanAttrs="false" CleanDim="false" TrackStatus="true" MaxJobQueues="0">' || chr(10) || chr(10) ;
         -- 13/10/2008 CR: Commented out two lines below
--         job_xml := job_xml || '<BuildList XMLIDref="ECNS.CUBE" />' || chr(10) ;
--         job_xml := job_xml || chr(10) || '</BuildDatabase>' ;
         
         pkg_task_manager.add_xml_generic_task_step(task_id,aw_name,'CUBE','ECNS', job_xml);
         upd_stmt:='declare begin ECNS_CUBE_LOAD_CR56.update_load('||load_id||',''XML LOAD COMPLETED''); end; ';
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,upd_stmt);

         upd_stmt:=' update ECNS_SC_DISPLAY_DIM set display=''Y'' where sc ='''||sc_id||''' ';
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,upd_stmt);
         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'commit');

         FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_DML(task_id,'ECNS_SC_DISPLAY(ECNS_SC '''||sc_id||''') =''Y''','x','x');
         IF (dependsOn IS NOT NULL) THEN
            FINANCE.PKG_TASK_MANAGER.SET_DEPENDSON(task_id,dependsOn);
         END IF;

         pkg_task_manager.AddStep_AWCommit(task_id);
        pkg_task_manager.enqueuetask(task_id);
   --  pkg_task_manager.add_xml_generic_task_step(task_id,aw_name,'DIMENSION','ECNS_SC',null);

   -- header1:='<BuildDatabase  Id="Action5" AWName="**PLACE_HOLDER**" BuildType="EXECUTE" RunSolve="true" CleanMeasures="false" CleanAttrs="false" CleanDim="false" TrackStatus="true" MaxJobQueues="0">';
  --  pkg_task_manager.add_xml_generic_task_step(task_id,aw_name,'CUBE','ECNS',header1);

    end;

    PROCEDURE do_load(sc_id varchar2,dependsOn NUMBER) as
        lv_load_id number(5);
        lv_ecns_exists number(2);
      --  VERSION_DOES_NOT_EXIST EXCEPTION;
    begin
        select count(*)
        into lv_ecns_exists
        from VW_BUS_CONS_DIM
        where BUS_CONS_SC_ID = sc_id;

        DELETE FROM ECNS_SC_DISPLAY_DIM WHERE SC=SC_ID;
        INSERT INTO ECNS_SC_DISPLAY_DIM VALUES (sc_id,'N');
        COMMIT;

        select EDF_NHH_T_ECNS_CUBE_LOAD_seq.nextval
        into lv_load_id
        from dual;

        if (lv_ecns_exists=1) THEN
            DBMS_OUTPUT.PUT_LINE('YES');
            INSERT INTO EDF_NHH_T_ECNS_CUBE_LOAD VALUES(SC_ID,'TASK CREATED',NULL,NULL,SYSDATE,lv_load_id);
            COMMIT;
            CREATE_TASK(sc_id,lv_load_id,dependsOn);
        END IF;
        if (lv_ecns_exists<>1) THEN
            DBMS_OUTPUT.PUT_LINE('NO');
            INSERT INTO EDF_NHH_T_ECNS_CUBE_LOAD VALUES(SC_ID,'ECNS SC DOES NOT EXIST',NULL,NULL,SYSDATE,lv_load_id);
            COMMIT;
            RAISE_APPLICATION_ERROR(-20000,'ECNS SC '||SC_ID||' DOES NOT EXITS');
        END IF;
    end;

    PROCEDURE update_load(p_load_id number, message varchar2) as
    begin
        IF ( message ='XML LOAD STARTED') THEN
            UPDATE EDF_NHH_T_ECNS_CUBE_LOAD
            SET STATUS = message,
            START_TIME = sysdate
            WHERE LOAD_ID=p_load_id;
        END IF;
-- 02/10/08 CR: Message changed to CURRENT
        IF ( message ='XML LOAD COMPLETED') THEN
            UPDATE EDF_NHH_T_ECNS_CUBE_LOAD
            SET STATUS = 'CURRENT',
            END_TIME = sysdate
            WHERE LOAD_ID=p_load_id;
        END IF;
        commit;
    end;
end;
/