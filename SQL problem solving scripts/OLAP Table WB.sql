    PROCEDURE writeback_gas_sett
    ( version IN varchar2, writeback_mode IN varchar2 DEFAULT 'FULL')
    AS

        start_date_raw  varchar2(20);
        end_date_raw    varchar2(20);

        startDate       date;
        endDate         date;

        thisdate        date;

        tmp             varchar2(4000);

    BEGIN

        gv_procedure := 'writeback_gas_sett';
        writeLog('Starting for version : ' || version);

        dbms_aw.execute('AW ATTACH GMF_AW.GMF');

        -- Limit Levels to avoid having to bring them back in the view

        limit_dim_to_level('PROFILE_CLASS', 'BASE');
        limit_dim_to_level('GAS_LICENCE', 'BASE');
        limit_dim_to_level('GAS_SITE_TYPE', 'BASE');
        limit_dim_to_level('GSP_GROUP_ID', 'BASE');
        limit_dim_to_level('GAS_TRANSPORTER', 'BASE');
        limit_dim_to_level('LDZ', 'EXIT_ZONE');
        limit_dim_to_level('EUC', 'EUC');

        CASE
           WHEN writeback_mode = 'FULL' THEN limit_dim_to_level('G_GM_ITEM', 'BASE');
           WHEN writeback_mode = 'OVR' THEN limit_gas_item_dim_to_overlay;
        END CASE;

        dbms_aw.execute('lmt G_FC_GM_VER TO '''||version||'''');

        dbms_aw.execute('CALL COPY_PARTITION_COMPOSITE (''G_FC_GM_SETT_PRT_COMPOSITE'' ''G_FC_GM_SETT_OP_PARTITION_TEMPLATE'')');

        dbms_aw.run('shw G_FC_GM_VER_TIME_FROM',start_date_raw);
        dbms_aw.run('shw G_FC_GM_VER_TIME_TO',end_date_raw);

        startDate := to_date(start_date_raw, 'MON-YY');
        endDate   := to_date(end_date_raw, 'MON-YY');

        writeLog('Processing for version ''' || version || ''' between ' || startDate || ' and ' || endDate);

        thisdate := startDate;

        --This TRUNCATE should be unnecessary is it should have been performed after the previous cube maintain step
         truncate_wb_gas_sett;

        while thisdate <= enddate loop
            dbms_aw.execute('LMT TIME TO '''||to_char(thisdate,'MON-YY')||'''');
            dbms_aw.run('shw TIME',tmp);
            writeLog('Processing : '||tmp);


            INSERT /*+ append nologging */ INTO g_fc_gm_sett_wb
                (G_GM_ITEM, GAS_SITE_TYPE, GAS_LICENCE, GSP_GROUP_ID, GAS_TRANSPORTER, LDZ, EUC, TIME_ID, G_FC_GM_VER, gm)
            SELECT
                G_GM_ITEM, GAS_SITE_TYPE, GAS_LICENCE, GSP_GROUP_ID, GAS_TRANSPORTER, LDZ, EUC, to_date(TIME_ID,'MON-YY'), G_FC_GM_VER, GM
            FROM
                vw_g_fc_gm_sett_wb
            WHERE
                g_fc_gm_ver = version;

            writeLog('Processed : '||tmp);

            commit;

            thisdate := add_months(thisdate, 1);
        end loop;

        dbms_aw.execute('aw detach gmf_aw.gmf');
    END;
