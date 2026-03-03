declare
 task_id int;
 aw_name varchar2(50);
 task_name varchar2(200);
begin
    w_name:='GDF_B2B_AW.GDF_B2B';
    task_name:='allcompile';
    pkg_task_manager.createtask(aw_name ,task_name,task_id);
    FINANCE.PKG_TASK_MANAGER.ADDSTEP_RUN_SQL(task_id,'begin INSERT INTO FINANCE.WORKSTREAM (id, description) values (''GDF_B2B'', ''Gas B2B demand forecast'') ; commit; End ;');	
	pkg_task_manager.AddStep_AWCommit(task_id);
    pkg_task_manager.enqueuetask(task_id);
end;
