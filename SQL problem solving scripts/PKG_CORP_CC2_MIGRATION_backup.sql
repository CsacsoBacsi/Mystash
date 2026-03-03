CREATE OR REPLACE PACKAGE BODY pkg_corp_cc2_migration
IS
--*****************************************************************************  *
--*  2010 Eon                                                                    *
--*****************************************************************************  *
--*                                                                              *
--* System      : ICE                                                            *
--* Subsystem   : Corporate Credit Checking Pahse 2                              *
--*                                                                              *
--* Module      : pkg_corp_cc2_migration                                         *
--*                                                                              *
--* Description :  This package contains procedures that migrate:                *
--*                   - CorpCC Tracker 1 requests/responses                      *
--*                   - Historic Bureau data from IAvenue                        *
--*                   - Security deposits from Excel                             *
--*                   - Guarantees from Excel                                    *
--*                Corresponding procedures will delete anything that was        *
--*                migrated if it were deemed to be necessary.                   *
--*****************************************************************************  *
--*                      M O D I F I C A T I O N  L O G                          *
--*****************************************************************************  *
--*                                                                              *
--* Date       Author               Version  Description                         *
--* ---------  ------------------   -------  ----------------------------------  *
--* 10/08/2010 Csaba Riedlinger     1.0      Initial version                     *
--********************************************************************************

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to turn business monitoring on
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_busmon_toggle (p_entity_id COMPANY.ENTITY_ID%TYPE,
                                  p_action    VARCHAR2)
IS

  v_xml             XMLTYPE;
  v_accesscode      corp_cc2_parameter.parameter_str_value%TYPE;
  v_password        corp_cc2_parameter.parameter_str_value%TYPE;
  --Webservice data
  v_web_serv_url    corp_cc2_parameter.parameter_str_value%TYPE;
  v_soap_action     corp_cc2_parameter.parameter_str_value%TYPE;
  v_endpoint        corp_cc2_parameter.parameter_str_value%TYPE;
  v_req_start       corp_cc2_parameter.parameter_str_value%TYPE := '<ToggleBusinessMonitoringAlerts xmlns="http://www.eonenergy.com/webservices/">';
  v_req_endpoint    VARCHAR2(100) ;
  v_web_proxy       VARCHAR2(100) ;  
  v_proxy           VARCHAR2(100) ;  
  v_req_access      VARCHAR2(100) ;
  v_req_cust_ref    VARCHAR2(100) ;  
  v_req_pword       VARCHAR2(100) ;
  v_req_action      VARCHAR2(100) ;     
  v_req_end         VARCHAR2(20) := '</ToggleBusinessMonitoringAlerts>';
  v_request_string  VARCHAR2(4000);
  v_error_message   VARCHAR2(4000);
  v_company_reg     VARCHAR2(20);
  v_clob            CLOB;
  EXP_BUREAU_ERROR  EXCEPTION ;

BEGIN

    IF p_action NOT IN ('add', 'delete') THEN
        RAISE_APPLICATION_ERROR (-20005, 'Invalid action parameter. Must be either add or delete.') ;
    END IF ;

    -- Get company reg no
    SELECT a.COMPANY_REG_NO
           INTO v_company_reg
    FROM   COMPANY a
    WHERE  ENTITY_ID = p_entity_id ;

    --Get Webservice parameters
    --Get webservice URL
    SELECT parameter_str_value
           INTO v_web_serv_url
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'BUSMON_ENDPOINT_EQUIFAX_PROXY' ;

    --Get web proxy
    SELECT parameter_str_value
           INTO v_proxy
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'WEB_PROXY';

    --Get Soap Action
    SELECT parameter_str_value
           INTO v_soap_action
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'BUSMON_TOGGLE_SOAP_ACTION';

    --Get Equifax end point
    SELECT parameter_str_value
           INTO v_endpoint
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'EQUIFAX_ONLINE_URL' ;

    --Get accesscode and password
    pkg_corp_cc2_master.sp_equifax_parameters(p_accesscode => v_accesscode,
                                              p_password   => v_password) ;

    v_req_endpoint := '<endpoint>'         ||v_endpoint   ||'</endpoint>' ;
    v_req_access   := '<user>'             ||v_accesscode ||'</user>' ;
    v_req_pword    := '<password>'         ||v_password   ||'</password>' ;
    v_req_action   := '<action>'           ||p_action     ||'</action>' ;
    v_req_cust_ref := '<customerReference>'||v_company_reg||'</customerReference>' ;
    v_web_proxy    := '<proxy>'            ||v_proxy      ||'</proxy>' ;

    --Build request string
    v_request_string := v_req_start    ||
                        v_req_endpoint ||
                        v_req_access   ||
                        v_req_pword    ||
                        v_req_cust_ref ||
                        v_req_action   ||
                        v_web_proxy    ||
                        v_req_end;

    --Call web service
    pkg_corp_cc2_master.sp_soap_connection(p_webservice_url => v_web_serv_url,
                                           p_soap_action    => v_soap_action,
                                           p_request_string => v_request_string,
                                           p_response_xml   => v_xml,
                                           p_error_message  => v_error_message);

    COMMIT;

    --Make clob from response XML
    v_clob := v_xml.getClobVal();

/*    INSERT INTO corp_cc2_request_clob_tmp
           (response_id, request_xml, cre_date)
    VALUES (v_response_id, v_clob, SYSDATE);
    COMMIT;*/

    --Did Soap connection encounter an error
    IF v_error_message IS NULL THEN
        --Replace ampersand
        v_clob := regexp_replace(v_clob, '&', '&amp;');

        --Was there an error in the returning report
        IF INSTR(v_clob, '<error') > 0 THEN
           v_error_message := regexp_substr(regexp_replace(v_clob, '[[:space:]]',''), '<error>.+</error>');
           RAISE EXP_BUREAU_ERROR;
        END IF;

        FOR i IN (SELECT parameter_str_value
                  FROM   corp_cc2_parameter
                  WHERE parameter_name LIKE 'EQUIFAX_ONLINE_STRIP_STRING%')
        LOOP
            v_clob := REPLACE(v_clob, i.parameter_str_value);
        END LOOP;
    END IF ;

EXCEPTION
  WHEN EXP_BUREAU_ERROR THEN
 
       ROLLBACK ;         
END sp_busmon_toggle ;

PROCEDURE sp_busmon_get_alerts (p_from_date DATE, p_to_date DATE)
IS

xml_test CLOB := '<?xml version="1.0"?>
<portfolio session=''190966,81YkPLnhsLCzT,fRoitkqa,SSO''>
  <request function=''PAV''>
    <param7><![CDATA[search]]></param7>
    <param8><![CDATA[]]></param8>
    <param9><![CDATA[SBD]]></param9>
    <param10><![CDATA[date]]></param10>
    <param11><![CDATA[1]]></param11>
    <param12><![CDATA[01/01/2010]]></param12>
    <param13><![CDATA[01/03/2010]]></param13>
    <param14><![CDATA[]]></param14>
    <param15><![CDATA[default]]></param15>
  </request>
  <portfolio_alert_list>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[06001280]]></cro_number>
      <eventcode><![CDATA[NMSH]]></eventcode>
      <description><![CDATA[Shareholder now above monitor]]></description>
      <alert_date><![CDATA[05/01/10]]></alert_date>
      <silver_detail><![CDATA[Major shareholder Timothy Moore   has increased shareholding from 0% to 100%]]></silver_detail>
      <gold_detail><![CDATA[Major shareholder Timothy Moore   has increased shareholding from 0% to 100%]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x0000000059315024]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCCJ]]></eventcode>
      <description><![CDATA[New Company CCJ Lodged]]></description>
      <alert_date><![CDATA[07/01/10]]></alert_date>
      <silver_detail><![CDATA[A new CCJ has been matched to this company. Court KINGSTON UPON HULL, Case Number 9KH06612, Date 18/12/2009, Amount 3,040.00]]></silver_detail>
      <gold_detail><![CDATA[A new CCJ has been matched to this company. Court KINGSTON UPON HULL, Case Number 9KH06612, Date 18/12/2009, Amount 3,040.00]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x0000000058c38d67]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[00194561]]></cro_number>
      <eventcode><![CDATA[DIRA]]></eventcode>
      <description><![CDATA[Officer Appointed]]></description>
      <alert_date><![CDATA[09/01/10]]></alert_date>
      <silver_detail><![CDATA[A new Director has been appointed. Appointment Date: 01/12/2009, Name: MARC ARTHUR RONCHETTI, Address: 22 NEW ROAD, CROXLEY GREEN, RICKMANSWORTH, HERTFORDSHIRE, WD3 3EP, Nationality: BRITISH, Date of Birth: 13/04/1976.]]></silver_detail>
      <gold_detail><![CDATA[A new Director has been appointed. Appointment Date: 01/12/2009, Name: MARC ARTHUR RONCHETTI, Address: 22 NEW ROAD, CROXLEY GREEN, RICKMANSWORTH, HERTFORDSHIRE, WD3 3EP, Nationality: BRITISH, Date of Birth: 13/04/1976.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[100000160]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000583fbe80]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[00194561]]></cro_number>
      <eventcode><![CDATA[DIRR]]></eventcode>
      <description><![CDATA[Officer Resigned]]></description>
      <alert_date><![CDATA[09/01/10]]></alert_date>
      <silver_detail><![CDATA[A Director has resigned. Resignation Date: 01/12/2009, Name: SPENCER LOCK, Address: THE DOWER HOUSE, ITCHEN ABBAS, WINCHESTER, HAMPSHIRE, SO21 1BQ Nationality: BRITISH, Date of Birth: 28/01/1967]]></silver_detail>
      <gold_detail><![CDATA[A Director has resigned. Resignation Date: 01/12/2009, Name: SPENCER LOCK, Address: THE DOWER HOUSE, ITCHEN ABBAS, WINCHESTER, HAMPSHIRE, SO21 1BQ Nationality: BRITISH, Date of Birth: 28/01/1967]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[100000160]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x0000000058402ee6]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCJC]]></eventcode>
      <description><![CDATA[Company CCJ Cancelled]]></description>
      <alert_date><![CDATA[14/01/10]]></alert_date>
      <silver_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court KINGSTON UPON HULL, Case Number 9KH06612, Date 18/12/2009, Amount 3,040.00.]]></silver_detail>
      <gold_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court KINGSTON UPON HULL, Case Number 9KH06612, Date 18/12/2009, Amount 3,040.00.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000227e5e00]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[00061302]]></cro_number>
      <eventcode><![CDATA[CANR]]></eventcode>
      <description><![CDATA[Annual Return Image Available]]></description>
      <alert_date><![CDATA[15/01/10]]></alert_date>
      <silver_detail><![CDATA[An Annual Return Image, dated 04/01/2010, has been received and stored.]]></silver_detail>
      <gold_detail><![CDATA[An Annual Return Image, dated 04/01/2010, has been received and stored.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x000000004509d425]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCCJ]]></eventcode>
      <description><![CDATA[New Company CCJ Lodged]]></description>
      <alert_date><![CDATA[20/01/10]]></alert_date>
      <silver_detail><![CDATA[A new CCJ has been matched to this company. Court WEST LONDON, Case Number 9WL03941, Date 18/01/2010, Amount 200.00]]></silver_detail>
      <gold_detail><![CDATA[A new CCJ has been matched to this company. Court WEST LONDON, Case Number 9WL03941, Date 18/01/2010, Amount 200.00]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000568aa7e3]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[02743938]]></cro_number>
      <eventcode><![CDATA[CACC]]></eventcode>
      <description><![CDATA[Annual Accounts Image Available]]></description>
      <alert_date><![CDATA[20/01/10]]></alert_date>
      <silver_detail><![CDATA[An Annual Accounts Image, dated 30/09/2009, has been received and stored.]]></silver_detail>
      <gold_detail><![CDATA[An Annual Accounts Image, dated 30/09/2009, has been received and stored.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x0000000056b3dd6a]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[06001280]]></cro_number>
      <eventcode><![CDATA[CSCI]]></eventcode>
      <description><![CDATA[Score Check Increase]]></description>
      <alert_date><![CDATA[27/01/10]]></alert_date>
      <silver_detail><![CDATA[Score Check has Increased by 1 points.]]></silver_detail>
      <gold_detail><![CDATA[Score Check has Increased by 1 points.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x0000000007c9ed40]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[06001280]]></cro_number>
      <eventcode><![CDATA[CACC]]></eventcode>
      <description><![CDATA[Annual Accounts Image Available]]></description>
      <alert_date><![CDATA[29/01/10]]></alert_date>
      <silver_detail><![CDATA[An Annual Accounts Image, dated 30/11/2009, has been received and stored.]]></silver_detail>
      <gold_detail><![CDATA[An Annual Accounts Image, dated 30/11/2009, has been received and stored.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x000000000ac60fa2]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[06001280]]></cro_number>
      <eventcode><![CDATA[NREP]]></eventcode>
      <description><![CDATA[New Equifax Credit Report]]></description>
      <alert_date><![CDATA[01/02/10]]></alert_date>
      <silver_detail><![CDATA[New Equifax Credit Report available based on 30/11/2009 accounts.]]></silver_detail>
      <gold_detail><![CDATA[New Equifax Credit Report available based on 30/11/2009 accounts.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000179eba62]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[06001280]]></cro_number>
      <eventcode><![CDATA[CLIL]]></eventcode>
      <description><![CDATA[Credit Limit Increase(Current <= GBP10k)]]></description>
      <alert_date><![CDATA[01/02/10]]></alert_date>
      <silver_detail><![CDATA[The credit limit has increased by a percentage equal to or greater than the value you have selected. The Credit limit has been increased from GBP10000 to GBP12000.]]></silver_detail>
      <gold_detail><![CDATA[The credit limit has increased by a percentage equal to or greater than the value you have selected. The Credit limit has been increased from GBP10000 to GBP12000.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000179ebaa1]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[SC137656]]></cro_number>
      <eventcode><![CDATA[CACC]]></eventcode>
      <description><![CDATA[Annual Accounts Image Available]]></description>
      <alert_date><![CDATA[02/02/10]]></alert_date>
      <silver_detail><![CDATA[An Annual Accounts Image, dated 31/12/2008, has been received and stored.]]></silver_detail>
      <gold_detail><![CDATA[An Annual Accounts Image, dated 31/12/2008, has been received and stored.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x0000000055912128]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[02006000]]></cro_number>
      <eventcode><![CDATA[CCCJ]]></eventcode>
      <description><![CDATA[New Company CCJ Lodged]]></description>
      <alert_date><![CDATA[04/02/10]]></alert_date>
      <silver_detail><![CDATA[A new CCJ has been matched to this company. Court NORTHAMPTON CCBC, Case Number 0QT00742, Date 02/02/2010, Amount 153.00]]></silver_detail>
      <gold_detail><![CDATA[A new CCJ has been matched to this company. Court NORTHAMPTON CCBC, Case Number 0QT00742, Date 02/02/2010, Amount 153.00]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000542d0e8b]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CGPS]]></eventcode>
      <description><![CDATA[Other Gazette Information]]></description>
      <alert_date><![CDATA[11/02/10]]></alert_date>
      <silver_detail><![CDATA[A Claim Form has been recorded against this company. Details are: On 28/01/2010 a Claim Form was issued at London - Queen''s Bench against the subject Company at the following address:- 1 Churchill Place, London, E14 5HP.  The Plaintiff is Pentor Capital Ltd.  The Solicitor acting on behalf of the plaintiff is  of:- , , Fax number n/a, Telex Number n/a.  Case number 03532010.]]></silver_detail>
      <gold_detail><![CDATA[A Claim Form has been recorded against this company. Details are: On 28/01/2010 a Claim Form was issued at London - Queen''s Bench against the subject Company at the following address:- 1 Churchill Place, London, E14 5HP.  The Plaintiff is Pentor Capital Ltd.  The Solicitor acting on behalf of the plaintiff is  of:- , , Fax number n/a, Telex Number n/a.  Case number 03532010.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x000000005228d1c0]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[SC137656]]></cro_number>
      <eventcode><![CDATA[CSCI]]></eventcode>
      <description><![CDATA[Score Check Increase]]></description>
      <alert_date><![CDATA[15/02/10]]></alert_date>
      <silver_detail><![CDATA[Score Check has Increased by 4 points.]]></silver_detail>
      <gold_detail><![CDATA[Score Check has Increased by 4 points.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x00000000516c49ea]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[SC137656]]></cro_number>
      <eventcode><![CDATA[CPSI]]></eventcode>
      <description><![CDATA[Protect Score Improvement]]></description>
      <alert_date><![CDATA[15/02/10]]></alert_date>
      <silver_detail><![CDATA[Protect Score has seen an improvement at or greater than your selected value. Protect Score has improved from 20 to 70.]]></silver_detail>
      <gold_detail><![CDATA[Protect Score has seen an improvement at or greater than your selected value. Protect Score has improved from 20 to 70.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x00000000516c4a0b]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[SC137656]]></cro_number>
      <eventcode><![CDATA[NREP]]></eventcode>
      <description><![CDATA[New Equifax Credit Report]]></description>
      <alert_date><![CDATA[15/02/10]]></alert_date>
      <silver_detail><![CDATA[New Equifax Credit Report available based on 31/12/2008 accounts.]]></silver_detail>
      <gold_detail><![CDATA[New Equifax Credit Report available based on 31/12/2008 accounts.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[bs1]]></client_busref>
      <client_grpref><![CDATA[gp1]]></client_grpref>
      <unique_id><![CDATA[0x00000000516c5840]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCJS]]></eventcode>
      <description><![CDATA[Company CCJ Satisfied]]></description>
      <alert_date><![CDATA[16/02/10]]></alert_date>
      <silver_detail><![CDATA[A CCJ has been satisfied for this company. Court WEST LONDON, Case Number 7WL03395, Date 12/11/2007, Amount 469.00.]]></silver_detail>
      <gold_detail><![CDATA[A CCJ has been satisfied for this company. Court WEST LONDON, Case Number 7WL03395, Date 12/11/2007, Amount 469.00.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x00000000514bd003]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCJC]]></eventcode>
      <description><![CDATA[Company CCJ Cancelled]]></description>
      <alert_date><![CDATA[19/02/10]]></alert_date>
      <silver_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court WEST LONDON, Case Number 9WL03941, Date 18/01/2010, Amount 200.00.]]></silver_detail>
      <gold_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court WEST LONDON, Case Number 9WL03941, Date 18/01/2010, Amount 200.00.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x0000000050479760]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCJC]]></eventcode>
      <description><![CDATA[Company CCJ Cancelled]]></description>
      <alert_date><![CDATA[23/02/10]]></alert_date>
      <silver_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court MANCHESTER, Case Number 9MA07479, Date 04/12/2009, Amount 34,298.00.]]></silver_detail>
      <gold_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court MANCHESTER, Case Number 9MA07479, Date 04/12/2009, Amount 34,298.00.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x000000004f687244]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <portfolio_alert sms=''N''>
      <client_code><![CDATA[190966]]></client_code>
      <cro_number><![CDATA[01026167]]></cro_number>
      <eventcode><![CDATA[CCJC]]></eventcode>
      <description><![CDATA[Company CCJ Cancelled]]></description>
      <alert_date><![CDATA[01/03/10]]></alert_date>
      <silver_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court WOLVERHAMPTON, Case Number 9WV02331, Date 28/09/2009, Amount 695.00.]]></silver_detail>
      <gold_detail><![CDATA[A CCJ has been cancelled for this company & therefore will no longer appear on Equifax Credit Reports. Court WOLVERHAMPTON, Case Number 9WV02331, Date 28/09/2009, Amount 695.00.]]></gold_detail>
      <priority><![CDATA[000]]></priority>
      <client_busref><![CDATA[]]></client_busref>
      <client_grpref><![CDATA[]]></client_grpref>
      <unique_id><![CDATA[0x000000004e01e3a2]]></unique_id>
      <archived><![CDATA[no]]></archived>
      <read><![CDATA[no]]></read>
      <profile_name><![CDATA[default]]></profile_name>
    </portfolio_alert>
    <archived><![CDATA[]]></archived>
    <sortby><![CDATA[SBD]]></sortby>
    <searchtype><![CDATA[date]]></searchtype>
    <page><![CDATA[1]]></page>
    <startdate><![CDATA[01/01/2010]]></startdate>
    <enddate><![CDATA[01/03/2010]]></enddate>
    <profile_name><![CDATA[default]]></profile_name>
  </portfolio_alert_list>
  <portfolio_profile_setup>
    <client_code><![CDATA[190966]]></client_code>
    <service_level><![CDATA[G]]></service_level>
    <profile_name><![CDATA[default]]></profile_name>
    <alert_display_order>
      <display_order code=''SBB''><![CDATA[By Business Reference]]></display_order>
      <display_order code=''SBC''><![CDATA[By Company Number]]></display_order>
      <display_order code=''SBD'' selected=''yes''><![CDATA[By Date]]></display_order>
      <display_order code=''SBG''><![CDATA[By Group Reference]]></display_order>
      <display_order code=''SBN''><![CDATA[By Name]]></display_order>
    </alert_display_order>
    <alert_display_count>
      <display_count selected=''yes''><![CDATA[25]]></display_count>
      <display_count><![CDATA[50]]></display_count>
      <display_count><![CDATA[75]]></display_count>
    </alert_display_count>
    <alert_addresses>
      <mail_addr><![CDATA[andrew.fielder@equifax.com]]></mail_addr>
      <mail_addr/>
      <mail_addr/>
      <mail_addr/>
      <mail_addr/>
      <phone_number/>
      <phone_number/>
      <phone_number/>
      <phone_number/>
      <phone_number/>
      <sms_enabled>N</sms_enabled>
    </alert_addresses>
    <spread_price>.25</spread_price>
    <output_method>B</output_method>
    <output_frequency>D</output_frequency>
  </portfolio_profile_setup>
  <portfolio_profile_list>
    <client_code><![CDATA[190966]]></client_code>
    <service_level><![CDATA[G]]></service_level>
    <profile_names>
      <name dcl_profile=''Y''><![CDATA[ENSURE1]]></name>
      <name dcl_profile=''N''><![CDATA[default]]></name>
      <name dcl_profile=''N''><![CDATA[profile111/04/0853007]]></name>
      <name dcl_profile=''N''><![CDATA[profile211/04/0852921]]></name>
      <name dcl_profile=''N''><![CDATA[test1]]></name>
      <name><![CDATA[All]]></name>
    </profile_names>
  </portfolio_profile_list>
</portfolio>' ;

v_xml             XMLTYPE;
v_accesscode      corp_cc2_parameter.parameter_str_value%TYPE;
v_password        corp_cc2_parameter.parameter_str_value%TYPE;
--Webservice data
v_web_serv_url    corp_cc2_parameter.parameter_str_value%TYPE;
v_soap_action     corp_cc2_parameter.parameter_str_value%TYPE;
v_endpoint        corp_cc2_parameter.parameter_str_value%TYPE;
v_req_start       corp_cc2_parameter.parameter_str_value%TYPE := '<ToggleBusinessMonitoringAlerts xmlns="http://www.eonenergy.com/webservices/">';
v_req_endpoint    VARCHAR2(100) ;
v_web_proxy       VARCHAR2(100) ;  
v_proxy           VARCHAR2(100) ;
v_req_access      VARCHAR2(100) ;
v_req_pword       VARCHAR2(100) ;
v_req_from        VARCHAR2(100) ;     
v_req_to          VARCHAR2(100) ;
v_req_end         VARCHAR2(20) := '</ToggleBusinessMonitoringAlerts>';
v_request_string  VARCHAR2(4000);
v_error_message   VARCHAR2(4000);
v_clob            CLOB;
EXP_BUREAU_ERROR  EXCEPTION ;

CURSOR C1 IS SELECT EXTRACTVALUE (VALUE (x), '/portfolio_alert/eventcode') as EVENT_CODE,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/description') as DESCRIPTION,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/client_code') as CLIENT_CODE,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/cro_number') as COMPANY_REG_NO,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/alert_date') as ALERT_DATE,                    
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/silver_detail') as DETAIL1,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/gold_detail') as DETAIL2,                    
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/priority') as PRIORITY,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/client_busref') as CLIENT_BUS_REF,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/client_grpref') as CLIENT_GRP_REF,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/unique_id') as ALERT_ID,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/archived') as ARCHIVED,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/read') as READ,
                    EXTRACTVALUE (VALUE (x), '/portfolio_alert/profile_name') as PROFILE_NAME
          FROM TABLE (XMLSEQUENCE (EXTRACT (XMLTYPE (xml_test), '/portfolio/portfolio_alert_list/portfolio_alert'))) x ;

v_req_date DATE ;   -- Timestamp of when this alert report request was sent
v_cnt      NUMBER ; -- Number of alerts' counter
v_dupl_cnt NUMBER ; -- Duplicate  alert count
v_sqlerrm  VARCHAR2 (4000) ; -- Composite (code + msg) error message
v_alert_id NUMBER ; -- To test if a duplicate alert arrived

BEGIN

    --Get Webservice parameters
    --Get webservice URL
    SELECT parameter_str_value
           INTO v_web_serv_url
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'BUSMON_ENDPOINT_EQUIFAX_PROXY' ;

    --Get web proxy
    SELECT parameter_str_value
           INTO v_proxy
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'WEB_PROXY';

    --Get Soap Action
    SELECT parameter_str_value
           INTO v_soap_action
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'BUSMON_GET_ALERTS_SOAP_ACTION';

    --Get Equifax end point
    SELECT parameter_str_value
           INTO v_endpoint
    FROM   corp_cc2_parameter
    WHERE  parameter_name = 'EQUIFAX_ONLINE_URL' ;

    --Get accesscode and password
    pkg_corp_cc2_master.sp_equifax_parameters(p_accesscode => v_accesscode,
                                              p_password   => v_password) ;

    v_req_endpoint := '<endpoint>'         ||v_endpoint   ||'</endpoint>';
    v_req_access   := '<user>'             ||v_accesscode ||'</user>';
    v_req_pword    := '<password>'         ||v_password   ||'</password>';
    v_req_from     := '<from>'             ||p_from_date  ||'</from>' ;
    v_req_to       := '<to>'               ||p_to_date    ||'</to>';
    v_web_proxy    := '<proxy>'            ||v_proxy      ||'</proxy>';

    --Build request string
    v_request_string := v_req_start    ||
                        v_req_endpoint ||
                        v_req_access   ||
                        v_req_pword    ||
                        v_req_from     ||
                        v_req_to       ||
                        v_web_proxy    ||
                        v_req_end ;

    --Call web service
    pkg_corp_cc2_master.sp_soap_connection(p_webservice_url => v_web_serv_url,
                                           p_soap_action    => v_soap_action,
                                           p_request_string => v_request_string,
                                           p_response_xml   => v_xml,
                                           p_error_message  => v_error_message);

    COMMIT;

    --Make clob from response XML
    v_clob := v_xml.getClobVal () ;

/*    INSERT INTO corp_cc2_request_clob_tmp
           (response_id, request_xml, cre_date)
    VALUES (v_response_id, v_clob, SYSDATE);
    COMMIT;*/

    --Did Soap connection encounter an error
    IF v_error_message IS NULL THEN
        --Replace ampersand
        v_clob := regexp_replace(v_clob, '&', '&amp;');

        --Was there an error in the returning report
        IF INSTR(v_clob, '<error') > 0 THEN
           v_error_message := regexp_substr(regexp_replace(v_clob, '[[:space:]]',''), '<error>.+</error>');
           RAISE EXP_BUREAU_ERROR;
        END IF;

        FOR i IN (SELECT parameter_str_value
                  FROM   corp_cc2_parameter
                  WHERE parameter_name LIKE 'EQUIFAX_ONLINE_STRIP_STRING%')
        LOOP
            v_clob := REPLACE(v_clob, i.parameter_str_value);
        END LOOP;
    END IF ;

    v_req_date := SYSDATE ;

    -- Business Monitoring header table
    INSERT INTO CORP_CC2_BUSMON_ALERT_HEADER
           (ALERT_REQUEST_DATE, FROM_DATE, TO_DATE, NO_OF_ALERTS, STATUS, MESSAGE)
           VALUES (v_req_date, p_from_date, p_to_date, NULL, NULL, NULL) ;

    v_cnt := 0 ;
    v_dupl_cnt := 0 ;
    FOR c1_rec IN C1 LOOP
        v_cnt := v_cnt + 1 ;

        SELECT MAX (ALERT_ID_DEC)
               INTO v_alert_id
        FROM   CORP_CC2_BUSMON_ALERT_DETAIL
        WHERE  ALERT_ID_DEC = TO_NUMBER (SUBSTR (c1_rec.alert_id, 3), 'xxxxxxxxxxxxxxxxxxxx') ;

        IF v_alert_id IS NULL THEN
        
            INSERT INTO CORP_CC2_BUSMON_ALERT_DETAIL
                   (ALERT_ID, ALERT_ID_DEC, 
                    ALERT_REQUEST_DATE, EVENT_CODE, DESCRIPTION, CLIENT_CODE,
                    COMPANY_REG_NO, ALERT_DATE,
                    DETAIL1, DETAIL2, PRIORITY, CLIENT_BUS_REF,
                    CLIENT_GRP_REF, ARCHIVED, READ, PROFILE_NAME)
                    VALUES (c1_rec.alert_id, TO_NUMBER (SUBSTR (c1_rec.alert_id, 3), 'xxxxxxxxxxxxxxxxxxxx'),
                            v_req_date, c1_rec.event_code, c1_rec.description, c1_rec.client_code,
                            c1_rec.company_reg_no, TO_DATE (c1_rec.alert_date, 'DD/MM/YY'),
                            c1_rec.detail1, c1_rec.detail2, c1_rec.priority, c1_rec.client_bus_ref,
                            c1_rec.client_grp_ref, c1_rec.archived, c1_rec.read, c1_rec.profile_name) ;

        ELSE
            v_dupl_cnt := v_dupl_cnt + 1 ;
        END IF ;
    END LOOP ;
    
    UPDATE CORP_CC2_BUSMON_ALERT_HEADER
           SET STATUS            = 'OK',
               MESSAGE           = 'Portfolio alerts processed successfully',
               NO_OF_ALERTS      = v_cnt,
               NO_OF_DUPL_ALERTS = v_dupl_cnt
    WHERE  ALERT_REQUEST_DATE = v_req_date ;

    COMMIT ;
    
    EXCEPTION
        WHEN OTHERS THEN
            v_sqlerrm := SUBSTR (SQLCODE || ': ' || SQLERRM, 1, 4000) ;
            ROLLBACK ;        
            
            UPDATE CORP_CC2_BUSMON_ALERT_HEADER
                   SET STATUS       = 'ERROR',
                       MESSAGE      = 'Error during processing of portfolio alerts: ' || v_sqlerrm
            WHERE  ALERT_REQUEST_DATE = v_req_date ;


END sp_busmon_get_alerts ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to migrate CorpCC Tracker 1 requests/responses
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_cc1
IS

-- Declarations
-- Cursors
CURSOR C1 IS -- All Complete or Appeal completed requests which have not yet been migrated
       SELECT a.*
       FROM   CORP_CC_REQUEST a
       WHERE  a.STATUS_ID IN (8, 10)
              AND NOT EXISTS (SELECT NULL
                              FROM   CORP_CC2_MIGRATE_CC1 b
                              WHERE  b.REQUEST_ID = a.REQUEST_ID) ;

CURSOR C2 (c_request_id CREDIT_CHECK_RESPONSE.REQUEST_ID%TYPE) IS -- Response corresponding to request (max 1 row only)
       SELECT a.*
       FROM   CORP_CC_RESPONSE a,
              CREDIT_CHECK_RESPONSE b
       WHERE  a.RESPONSE_ID = b.RESPONSE_ID
              AND b.REQUEST_ID = c_request_id ;

-- Local variables
v_request_id    CORP_CC2_REQUEST.REQUEST_ID%TYPE ;
v_response_id   CORP_CC2_RESPONSE.RESPONSE_ID%TYPE ;
v_entity_id     CREDIT_CHECK_REQUEST.ENTITY_ID%TYPE ;
v_req_user_id   CREDIT_CHECK_REQUEST.USER_ID%TYPE ;
v_resp_user_id  CREDIT_CHECK_RESPONSE.USER_ID%TYPE ;
v_sqlerrm       VARCHAR2 (4000) ; -- Composite (code + msg) error message
v_segment       VARCHAR2 (100) ;
v_grade         CORP_CC2_BUREAU_RESPONSE.SCORE_CHECK_GRADE%TYPE ;
v_dec_type      CORP_CC2_RESPONSE_DECISION.DECISION_TYPE%TYPE ;
v_dec_outcome   CORP_CC2_RESPONSE_DECISION.DECISION_OUTCOME_ID%TYPE ;
v_max_pay_terms CORP_CC2_RESPONSE_DECISION.MAX_PAYMENT_TERMS%TYPE ;
v_pay_method    CORP_CC2_RESPONSE_DECISION.PAYMENT_METHOD%TYPE ;
v_iav_rating    CORP_CC2_RESPONSE_DECISION.IAVENUE_RATING%TYPE ;
v_ref_reason1   CORP_CC2_RESPONSE_INT_REFERRAL.REFERRAL_REASON_ID%TYPE ;
v_ref_reason2   CORP_CC2_RESPONSE_INT_REFERRAL.REFERRAL_REASON_ID%TYPE ;
v_ref_reason3   CORP_CC2_RESPONSE_INT_REFERRAL.REFERRAL_REASON_ID%TYPE ;
v_any_response  PLS_INTEGER ; -- Indicates whether a response was found in Corp CC1 or not
v_req_date      CREDIT_CHECK_REQUEST.REQUEST_DATE%TYPE ;
v_resp_date     CREDIT_CHECK_RESPONSE.RESPONSE_DATE%TYPE ;

-- Counters
v_req_cnt       PLS_INTEGER := 0 ;
v_req_ok        PLS_INTEGER := 0 ;
v_req_error     PLS_INTEGER := 0 ;

BEGIN

    -- Main loop. For each and every Corp CC1 request
    FOR c1_rec IN C1 LOOP -- For each and every completed Corp Cc1 request
        v_req_cnt := v_req_cnt + 1 ;
        v_request_id := c1_rec.request_id ;

        -- Register this request in migration helper/audit table
        INSERT INTO CORP_CC2_MIGRATE_CC1 (REQUEST_ID, RESPONSE_ID, STATUS, MESSAGE, CREATED_DATE)
               VALUES (v_request_id, NULL, NULL, NULL, SYSDATE) ; -- Audit table

        COMMIT ;

        BEGIN -- Block needed for error handling

            SELECT ENTITY_ID, USER_ID, REQUEST_DATE
                   INTO v_entity_id, v_req_user_id, v_req_date
            FROM   CREDIT_CHECK_REQUEST
            WHERE  REQUEST_ID = v_request_id ;

            -- Header table
            INSERT INTO CORP_CC2_REQUEST
                   (REQUEST_ID, CREATED_DATE, REQUEST_TYPE, PRIORITY, CURRENT_STATUS)
                   VALUES (v_request_id,  v_req_date, 1, c1_rec.priority_id, c1_rec.status_id) ;

            -- Lookup segment desc
            SELECT MAX (DESCRIPTION) INTO v_segment
            FROM   CORP_CC_SALES_SEGMENT
            WHERE  SALES_SEGMENT_ID = c1_rec.sales_segment_id ;

            -- Standard request
            INSERT INTO CORP_CC2_REQUEST_STD
                   (request_id, basket_request_id, bulk_request_id, tender_type,
                    account_manager_id, cp_id, reg_charity_number, sme_split, sector,
                    government_flag, international_flag,
                    contract_start_date, contract_duration,
                    total_annual_exposure, contract_value, annual_tender_exposure,
                    annual_existing_exposure, tender_comment, published_to_iavenue, gross_margin,
                    segment, duos_pass_through_flag)
                    VALUES (v_request_id, NULL, NULL, c1_rec.tender_type_id,
                            -- c1_rec.account_manager_id
                            'C10879', c1_rec.cp_id, c1_rec.reg_charity_number, c1_rec.sme_split, c1_rec.sector,
                            DECODE (c1_rec.govt_public_sect_flag, 'Y', 'Y', 'N'), decode (c1_rec.company_location_flag, 'N', 'Y', 'U', 'N', NULL),
                            c1_rec.contract_start_date, c1_rec.contract_duration,
                            nvl (c1_rec.annual_tender_exposure, 0) + nvl (c1_rec.annual_existing_exposure, 0), c1_rec.contract_value, c1_rec.annual_tender_exposure,
                            c1_rec.annual_existing_exposure, c1_rec.tender_comments, c1_rec.published_to_iavenue, NULL,
                            v_segment, NULL) ;

            -- Sub requests (per Fuel type)
            CASE c1_rec.fuel_type_id
                WHEN 1 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 1) ;
                WHEN 2 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 2) ;
                WHEN 3 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 3) ;
                WHEN 4 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 1) ;
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 2) ;
                WHEN 5 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 1) ;
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 3) ;
                WHEN 6 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 2) ;
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 3) ;
                WHEN 7 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 1) ;
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 2) ;
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 3) ;
                WHEN 8 THEN
                    INSERT INTO CORP_CC2_REQUEST_SUB (REQUEST_ID, FUEL_TYPE_ID) VALUES (v_request_id, 5) ;
            END CASE ;

            -- "Loop over" responses. There will only be one always.
            v_any_response := 0 ;
            FOR c2_rec IN C2 (c1_rec.request_id) LOOP
                v_response_id := c2_rec.response_id ;
                v_any_response := 1 ;

                SELECT USER_ID, RESPONSE_DATE
                       INTO v_resp_user_id, v_resp_date
                FROM   CREDIT_CHECK_RESPONSE
                WHERE  RESPONSE_ID = v_response_id ;

                -- Header table
                INSERT INTO CORP_CC2_RESPONSE
                       (RESPONSE_ID, GUARANTEE_TYPE_ID, DEPOSIT_REQ,
                        GUARANTEE_REQ, CREATED_DATE, USER_ID)
                       VALUES (v_response_id, c2_rec.guarantee_type_id, c2_rec.deposit_amount_required,
                               c2_rec.guarantee_amount_requested, v_resp_date, v_resp_user_id) ;

                -- Derive score check grade
                CASE c2_rec.external_rating_id
                    WHEN 9  THEN v_grade := 'A+' ; WHEN 10 THEN v_grade := 'A' ;
                    WHEN 11 THEN v_grade := 'A-';  WHEN 12 THEN v_grade := 'B+' ;
                    WHEN 13 THEN v_grade := 'B' ;  WHEN 14 THEN v_grade := 'B-' ;
                    WHEN 15 THEN v_grade := 'C+' ; WHEN 16 THEN v_grade := 'C' ;
                    WHEN 17 THEN v_grade := 'C-' ; WHEN 18 THEN v_grade := 'D+' ;
                    WHEN 19 THEN v_grade := 'D' ;  WHEN 20 THEN v_grade := 'D-' ;
                    WHEN 21 THEN v_grade := 'E+' ; WHEN 22 THEN v_grade := 'E' ;
                    WHEN 23 THEN v_grade := 'E-' ; WHEN 24 THEN v_grade := 'F+' ;
                    WHEN 25 THEN v_grade := 'F' ;  WHEN 26 THEN v_grade := 'F-' ;
                    WHEN 27 THEN v_grade := 'G' ;  WHEN 28 THEN v_grade := 'I' ;
                    WHEN 29 THEN v_grade := 'O' ;  WHEN 30 THEN v_grade := 'N' ;
                    WHEN 31 THEN v_grade := 'NT' ; WHEN 32 THEN v_grade := 'NA' ;
                    WHEN 33 THEN v_grade := 'NR' ;
                END CASE ;

                -- Bureau response
                INSERT INTO CORP_CC2_BUREAU_RESPONSE
                       (RESPONSE_ID, BUREAU_ID, VERSION_ID, SCORE_CHECK_GRADE,
                        SCORE_CHECK_DATE, SCORE_CHECK_SCORE,
                        CREDIT_LIMIT, RESPONSE_TYPE)
                       VALUES (v_response_id, 2, 1, v_grade,
                               c2_rec.credit_search_date, c2_rec.credit_score,
                               c2_rec.credit_limit, 'P') ;

                -- Response decision
                -- Max payment terms
                CASE c2_rec.payment_terms_id
                    WHEN 1 THEN v_max_pay_terms := 0 ;  WHEN 2 THEN v_max_pay_terms := 10 ;
                    WHEN 3 THEN v_max_pay_terms := 14 ; WHEN 4 THEN v_max_pay_terms := 21 ;
                    WHEN 5 THEN v_max_pay_terms := 30 ;
                END CASE ;
                -- Payment method
                CASE c2_rec.payment_method_id
                    WHEN 1 THEN
                        IF c2_rec.deposit_amount_required > 0 THEN
                            v_pay_method := 2 ;
                        ELSIF c2_rec.deposit_amount_required = 0 THEN
                            v_pay_method := 4 ;
                        ELSIF c2_rec.guarantee_amount_requested > 0 THEN
                            v_pay_method := 3 ;
                        END IF ;
                    WHEN 2 THEN v_pay_method := -1 ;
                    WHEN 3 THEN v_pay_method := 1 ;
                END CASE ;
                -- IAvenue rating
                CASE c2_rec.internal_rating_id
                    WHEN 1  THEN v_iav_rating := 1 ; WHEN 2  THEN v_iav_rating := 4 ;
                    WHEN 3  THEN v_iav_rating := 2 ; WHEN 4  THEN v_iav_rating := 3 ;
                    WHEN 9  THEN v_iav_rating := 5 ; WHEN 10 THEN v_iav_rating := 6 ;
                END CASE ;

                -- Decision outcome 1
                CASE c2_rec.external_decision_id
                    WHEN -1 THEN v_dec_outcome := 65 ; WHEN 1  THEN v_dec_outcome := 2 ;
                    WHEN 2  THEN v_dec_outcome := 3 ;  WHEN 3  THEN v_dec_outcome := 1 ;
                    WHEN 4  THEN v_dec_outcome := 4 ;
                END CASE ;
                -- Decision type
                v_dec_type := 'M' ; -- Manual credit check
                -- Populate table with different time stamps
                INSERT INTO CORP_CC2_RESPONSE_DECISION
                       (RESPONSE_ID, DECISION_OUTCOME_ID, DECISION_TYPE,
                        IAVENUE_RATING, DECISION_SOURCE, MAX_PAYMENT_TERMS,
                        PAYMENT_METHOD, CREATED_DATE, USER_ID)
                        VALUES (v_response_id, v_dec_outcome, v_dec_type,
                               v_iav_rating, 2, v_max_pay_terms,
                               v_pay_method, v_resp_date, v_resp_user_id) ;

                -- Decision outcome 2
                CASE c2_rec.internal_decision_id
                    WHEN -1 THEN v_dec_outcome := 65 ; WHEN 1  THEN v_dec_outcome := 2 ;
                    WHEN 2  THEN v_dec_outcome := 3 ;  WHEN 3  THEN v_dec_outcome := 4 ;
                END CASE ;

                -- Populate table with different time stamps
                INSERT INTO CORP_CC2_RESPONSE_DECISION
                       (RESPONSE_ID, DECISION_OUTCOME_ID, DECISION_TYPE,
                        IAVENUE_RATING, DECISION_SOURCE, MAX_PAYMENT_TERMS,
                        PAYMENT_METHOD, CREATED_DATE, USER_ID)
                        VALUES (v_response_id, v_dec_outcome, v_dec_type,
                                v_iav_rating, 2, v_max_pay_terms,
                                v_pay_method, v_resp_date + 1/(24*60*60), v_resp_user_id) ; -- Second later (as it is part of the primary key!)

                -- Decision outcome 2
                CASE c2_rec.internal_reason_id
                    WHEN 1  THEN v_dec_outcome := 2 ;  WHEN 2  THEN v_dec_outcome := 3 ;
                    WHEN 3  THEN v_dec_outcome := 3 ;  WHEN 4  THEN v_dec_outcome := 3 ;
                    WHEN 7  THEN v_dec_outcome := 65 ; WHEN 9  THEN v_dec_outcome := 4 ;
                    WHEN 10 THEN v_dec_outcome := 2 ;
                END CASE ;

                -- Populate table with different time stamps
                INSERT INTO CORP_CC2_RESPONSE_DECISION
                       (RESPONSE_ID, DECISION_OUTCOME_ID, DECISION_TYPE,
                        IAVENUE_RATING, DECISION_SOURCE, MAX_PAYMENT_TERMS,
                        PAYMENT_METHOD, CREATED_DATE, USER_ID)
                        VALUES (v_response_id, v_dec_outcome, v_dec_type,
                                v_iav_rating, 2, v_max_pay_terms,
                                v_pay_method, v_resp_date + 2/(24*60*60), v_resp_user_id) ; -- Two seconds later (as it is part of the primary key!)

                -- Referrals
                CASE c2_rec.referral_reason_id
                    WHEN 1  THEN v_ref_reason1 := 2 ;  WHEN 2  THEN v_ref_reason1 := 4 ;
                    WHEN 3  THEN v_ref_reason1 := 36 ; WHEN 4  THEN v_ref_reason1 := 21 ;
                    WHEN 5  THEN v_ref_reason1 := 23 ; WHEN 6  THEN v_ref_reason1 := 24 ;
                    WHEN 7  THEN v_ref_reason1 := 25 ; WHEN 8  THEN v_ref_reason1 := 26 ;
                    WHEN 9  THEN v_ref_reason1 := 27 ; WHEN 10 THEN v_ref_reason1 := -1 ;
                    WHEN 11 THEN v_ref_reason1 := -1 ; WHEN 12 THEN v_ref_reason1 := -1 ;
                    WHEN 13 THEN v_ref_reason1 := 27 ; WHEN 14 THEN v_ref_reason1 := 28 ;
                    WHEN 15 THEN v_ref_reason1 := -1 ; WHEN 16 THEN v_ref_reason1 := -1 ;
                    WHEN 17 THEN v_ref_reason1 := -1 ; WHEN 18 THEN v_ref_reason1 := -1 ;
                    WHEN 19 THEN v_ref_reason1 := 39 ; WHEN 20 THEN v_ref_reason1 := -1 ;
                    WHEN 21 THEN v_ref_reason1 := -1 ; WHEN 22 THEN v_ref_reason1 := 27 ;
                    WHEN 23 THEN v_ref_reason1 := 30 ; WHEN 24 THEN v_ref_reason1 := -1 ;
                    WHEN 25 THEN v_ref_reason1 := -1 ; WHEN 26 THEN v_ref_reason1 := -1 ;
                    WHEN 27 THEN v_ref_reason1 := -1 ; WHEN 28 THEN v_ref_reason1 := -1 ;
                    WHEN 29 THEN v_ref_reason1 := 34 ; WHEN 30 THEN v_ref_reason1 := -1 ;
                    WHEN 31 THEN v_ref_reason1 := -1 ; WHEN 32 THEN v_ref_reason1 := -1 ;
                    WHEN 33 THEN v_ref_reason1 := -1 ; WHEN 34 THEN v_ref_reason1 := -1 ;
                    WHEN 35 THEN v_ref_reason1 := -1 ; WHEN 36 THEN v_ref_reason1 := -1 ;
                    WHEN 37 THEN v_ref_reason1 := -1 ; WHEN 38 THEN v_ref_reason1 := -1 ;
                    WHEN 39 THEN v_ref_reason1 := -1 ; WHEN 40 THEN v_ref_reason1 := 31 ;
                    WHEN 41 THEN v_ref_reason1 := 36 ; WHEN 42 THEN v_ref_reason1 := 37 ;
                    WHEN 43 THEN v_ref_reason1 := -1 ; WHEN 44 THEN v_ref_reason1 := -1 ;
                    WHEN 45 THEN v_ref_reason1 := 38 ; WHEN 46 THEN v_ref_reason1 := -1 ;
                    WHEN 47 THEN v_ref_reason1 := 38 ; WHEN 48 THEN v_ref_reason1 := -1 ;
                    WHEN 49 THEN v_ref_reason1 := 39 ; WHEN 50 THEN v_ref_reason1 := -1 ;
                END CASE ;

                CASE c2_rec.decline_reason_id
                    WHEN 1  THEN v_ref_reason2 := 36 ; WHEN 2  THEN v_ref_reason2 := 37 ;
                    WHEN 3  THEN v_ref_reason2 := -1 ; WHEN 4  THEN v_ref_reason2 := -1 ;
                    WHEN 5  THEN v_ref_reason2 := 38 ; WHEN 6  THEN v_ref_reason2 := -1 ;
                    WHEN 7  THEN v_ref_reason2 := 38 ;
                END CASE ;

                IF c2_rec.recession_rules_met = 'Y' THEN
                    v_ref_reason3 := 3 ;
                ELSE
                    v_ref_reason3 := nvl (v_ref_reason1, v_ref_reason2) ;
                END IF ;

                -- Create as many records as different referral reasons there are
                FOR c3_rec IN (SELECT REFERRAL_REASON_ID
                               FROM   (SELECT v_ref_reason1 AS REFERRAL_REASON_ID FROM DUAL
                                       UNION
                                       SELECT v_ref_reason2 AS REFERRAL_REASON_ID FROM DUAL
                                       UNION
                                       SELECT v_ref_reason3 AS REFERRAL_REASON_ID FROM DUAL)) LOOP

                     INSERT INTO CORP_CC2_RESPONSE_INT_REFERRAL
                            (RESPONSE_ID, VERSION_ID, REFERRAL_REASON_ID)
                            VALUES (v_response_id, 1, c3_rec.referral_reason_id) ;
                 END LOOP ;
            END LOOP ;

            IF v_any_response = 1 THEN
                v_req_ok := v_req_ok + 1 ;
                -- Update migration audit/helper table with known response ids
                UPDATE CORP_CC2_MIGRATE_CC1
                       SET RESPONSE_ID = v_response_id,
                           STATUS      = 'OK',
                           MESSAGE     = 'Migrated successfully'
                WHERE  REQUEST_ID      = v_request_id ;
            ELSE
                v_req_error := v_req_error + 1 ;
                ROLLBACK ;
                -- Register error in audit table
                UPDATE CORP_CC2_MIGRATE_CC1
                       SET STATUS  = 'ERROR',
                           MESSAGE = 'No response found for request'
                WHERE  REQUEST_ID  = v_request_id ;
            END IF ;

            COMMIT ;

            -- Exception handler
            EXCEPTION
                WHEN OTHERS THEN

                    v_sqlerrm := SUBSTR (SQLCODE || ': ' || SQLERRM, 1, 4000) ;
                    ROLLBACK ;

                    -- Register error in audit table
                    UPDATE CORP_CC2_MIGRATE_CC1
                           SET STATUS  = 'ERROR',
                               MESSAGE = v_sqlerrm
                    WHERE  REQUEST_ID  = v_request_id ;

                    COMMIT ;
                    v_req_error := v_req_error + 1 ;
        END ;

    END LOOP ;

    COMMIT ;

    -- Final stats
    dbms_output.put_line ('Number of Corp CC1 requests found                : ' || v_req_cnt) ;
    dbms_output.put_line ('Number of Corp CC1 requests migrated successfully: ' || v_req_ok) ;
    dbms_output.put_line ('Number of Corp CC1 requests failed migration     : ' || v_req_error) ;

    -- Exception handler
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK ;

END sp_migrate_cc1 ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to delete migrated CorpCC Tracker 1 requests/responses
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_cc1_delete
IS

BEGIN
    -- Delete responses first
    DELETE FROM CORP_CC2_RESPONSE_INT_REFERRAL
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_CC1
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from RESPONSE_INT_REFERRAL table.') ;

    DELETE FROM CORP_CC2_RESPONSE_DECISION
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_CC1
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from RESPONSE_DECISION table.') ;

    DELETE FROM CORP_CC2_BUREAU_RESPONSE
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_CC1
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from BUREAU_RESPONSE table.') ;

    DELETE FROM CORP_CC2_RESPONSE
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_CC1
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from RESPONSE table.') ;

    -- Requests next
    DELETE FROM CORP_CC2_REQUEST_SUB
    WHERE  REQUEST_ID IN (SELECT REQUEST_ID
                          FROM   CORP_CC2_MIGRATE_CC1
                          WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from REQUEST_SUB table.') ;

    DELETE FROM CORP_CC2_REQUEST_STD
    WHERE  REQUEST_ID IN (SELECT REQUEST_ID
                          FROM   CORP_CC2_MIGRATE_CC1
                          WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from REQUEST_STD table.') ;

    DELETE FROM CORP_CC2_REQUEST
    WHERE  REQUEST_ID IN (SELECT REQUEST_ID
                          FROM   CORP_CC2_MIGRATE_CC1
                          WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from REQUEST table.') ;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE CORP_CC2_MIGRATE_CC1' ; 

    -- EXECUTE IMMEDIATE 'TRUNCATE TABLE CORP_CC2_CC1_MIGRATION' ;

    -- COMMIT ;
    dbms_output.put_line ('No commit was issued. Please check results before committing the DB.') ;

END sp_migrate_cc1_delete ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to migrate historic bureau data from IAvenue
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_iav_bureau_data
IS

-- Declarations
-- Cursors
CURSOR C1 IS -- All historical bureau responses which have not yet been migrated
       SELECT a.*
       FROM   SAM.BULK_UPLOAD_BUREAU_DATA@IAVELIVE.WORLD a
       WHERE  ICE_CUSTOMER_ID IS NOT NULL 
              AND NOT EXISTS (SELECT NULL
                              FROM   CORP_CC2_MIGRATE_BUREAU_DATA b
                              WHERE  b.ICE_CUSTOMER_ID = a.ICE_CUSTOMER_ID
                                     AND b.SCORE_DATE = a.SCORE_DATE) ;

-- Local variables
v_request_id    CORP_CC2_REQUEST.REQUEST_ID%TYPE ;
v_response_id   CORP_CC2_RESPONSE.RESPONSE_ID%TYPE ;
v_entity_id     CREDIT_CHECK_REQUEST.ENTITY_ID%TYPE ;
v_ici           ENTITY_RELATIONSHIP.ICE_CUSTOMER_ID%TYPE ;
v_sqlerrm       VARCHAR2 (4000) ; -- Composite (code + msg) error message

-- Counters
v_cnt           PLS_INTEGER := 0 ;
v_ok            PLS_INTEGER := 0 ;
v_error         PLS_INTEGER := 0 ;


BEGIN

    FOR c1_rec IN C1 LOOP
       v_cnt := v_cnt + 1 ;
       v_ici := c1_rec.ice_customer_id ;
    
       -- Register this burea data in migration helper/audit table
        INSERT INTO CORP_CC2_MIGRATE_BUREAU_DATA (ICE_CUSTOMER_ID, ENTITY_ID, REQUEST_ID, STATUS, MESSAGE, CREATED_DATE, SCORE_DATE)
               VALUES (c1_rec.ice_customer_id, NULL, NULL, NULL, NULL, SYSDATE, c1_rec.score_date) ; -- Audit table

        COMMIT ;

        BEGIN -- Block needed for error handling

            -- Lookup entity
            SELECT MAX (ENTITY_ID) INTO v_entity_id
            FROM   ENTITY_RELATIONSHIP
            WHERE  ENTITY_ROLE_ID = 2 -- Customer
                   AND ICE_CUSTOMER_ID = c1_rec.ice_customer_id ;
        
            IF v_entity_id IS NULL THEN
                UPDATE CORP_CC2_MIGRATE_BUREAU_DATA
                       SET STATUS  = 'ERROR',
                       MESSAGE = 'Could not find entity based on ICE Customer id: ' || v_ici
                WHERE  ICE_CUSTOMER_ID  = v_ici ;
                
                v_error := v_error + 1 ;
            ELSE           
                -- Update migration audit/helper table with known entity_id
                UPDATE CORP_CC2_MIGRATE_BUREAU_DATA
                       SET ENTITY_ID = v_entity_id
                WHERE  ICE_CUSTOMER_ID = v_ici ;         
            
                -- Header tables
                SELECT CORP_CC2_REQUEST_SEQ.NEXTVAL INTO v_request_id
                FROM DUAL ;

                -- Update migration audit/helper table with known request id
                UPDATE CORP_CC2_MIGRATE_BUREAU_DATA
                       SET REQUEST_ID = v_request_id
                WHERE  ICE_CUSTOMER_ID = v_ici ;

                -- Request              
                INSERT INTO CREDIT_CHECK_REQUEST
                       (REQUEST_ID, ENTITY_ID, REQUEST_DATE, USER_ID)
                       VALUES (v_request_id, v_entity_id, c1_rec.load_date, 'SYSTEM') ;
                   
                INSERT INTO CORP_CC2_REQUEST
                       (REQUEST_ID, CREATED_DATE, REQUEST_TYPE, PRIORITY, CURRENT_STATUS)
                        VALUES (v_request_id,  c1_rec.load_date, 1, 1, NULL) ;

                -- Response
                SELECT CORP_CC2_RESPONSE_SEQ.NEXTVAL INTO v_response_id
                FROM DUAL ;

                INSERT INTO CREDIT_CHECK_RESPONSE
                       (RESPONSE_ID, REQUEST_ID, RESPONSE_DATE, USER_ID)
                        VALUES (v_response_id, v_request_id, c1_rec.load_date, 'SYSTEM') ;

                INSERT INTO CORP_CC2_RESPONSE
                       (RESPONSE_ID, CREATED_DATE, USER_ID, DEPOSIT_REQ, GUARANTEE_REQ, CREDIT_RISK_COMMENTS)
                        VALUES (v_response_id, c1_rec.load_date, 'SYSTEM', NULL, NULL, NULL) ;        

                INSERT INTO CORP_CC2_BUREAU_RESPONSE
                       (response_id, bureau_id, version_id, bureau_cust_ref, reg_number,
                        reg_name, addr_line_1, addr_line_2, town, county, postcode,
                        tel_no, sic_code_1, sic_code_2, sic_code_3, sic_code_4,
                        equifax_ind_code, latest_acc_anl_date, status, protect_score,
                        credit_limit, eon_personal_limit, turnover, networth, 
                        no_of_ccjs, value_ccjs, ultimate_holding_co_no,
                        ultimate_holding_co_name, immediate_holding_co_no,
                        immediate_holding_co_name, score_check_score, score_check_grade,
                        score_check_date, response_type)
                        VALUES  (v_response_id, 2, 1, NULL, c1_rec.company_reg,
                                 c1_rec.customer_name, c1_rec.address_1, c1_rec.address_2, c1_rec.address_3, c1_rec.address_4, c1_rec.post_code,
                                 NULL, c1_rec.sic_code, NULL, NULL, NULL,
                                 c1_rec.sic_code, c1_rec.last_accounts, c1_rec.equifax_matching_flag, c1_rec.protect_score,
                                 c1_rec.bureau_limit, c1_rec.bureau_limit * 12, c1_rec.turnover, c1_rec.net_worth,
                                 c1_rec.no_ccjs, c1_rec.value_ccjs, NULL,
                                 NULL, c1_rec.holding_co_reg, 
                                 c1_rec.holding_name, c1_rec.risk_score, c1_rec.risk_band,
                                 c1_rec.score_date, 'C') ;

                -- Update migration audit/helper table with known response id
                UPDATE CORP_CC2_MIGRATE_BUREAU_DATA
                       SET RESPONSE_ID = v_response_id,
                           STATUS      = 'OK',
                           MESSAGE     = 'Migrated successfully'
                WHERE  ICE_CUSTOMER_ID = v_ici ;

                COMMIT ;
                
                v_ok := v_ok + 1 ;

            -- Exception handler
            
            END IF ;
                
            EXCEPTION
                WHEN OTHERS THEN

                    v_sqlerrm := SUBSTR (SQLCODE || ': ' || SQLERRM, 1, 4000) ;
                    ROLLBACK ;

                    -- Register error in audit table
                    UPDATE CORP_CC2_MIGRATE_BUREAU_DATA
                           SET STATUS  = 'ERROR',
                               MESSAGE = v_sqlerrm || ' ICE Customer id: ' || v_ici
                    WHERE  ICE_CUSTOMER_ID  = v_ici ;

                    COMMIT ;
                    v_error := v_error + 1 ;
    
        END ;
    
    END LOOP ;

    COMMIT ;

    -- Final stats
    dbms_output.put_line ('Number of rows in IAvenue bureau data            : ' || v_cnt) ;
    dbms_output.put_line ('Number of rows migrated successfully             : ' || v_ok) ;
    dbms_output.put_line ('Number of rows failed migration                  : ' || v_error) ;

    -- Exception handler
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK ;
            RAISE ;

END sp_migrate_iav_bureau_data ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure delete migrated historic bureau data from IAvenue
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_iav_bureau_delete
IS

BEGIN

    -- Delete responses first
    DELETE FROM CORP_CC2_BUREAU_RESPONSE
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_BUREAU_DATA
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from BUREAU_RESPONSE table.') ;

    DELETE FROM CORP_CC2_RESPONSE
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_BUREAU_DATA
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from RESPONSE table.') ;

    DELETE FROM CREDIT_CHECK_RESPONSE
    WHERE  RESPONSE_ID IN (SELECT RESPONSE_ID
                           FROM   CORP_CC2_MIGRATE_BUREAU_DATA
                           WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from CREDIT_CHECK_RESPONSE table.') ;

    -- Requests next
    DELETE FROM CORP_CC2_REQUEST
    WHERE  REQUEST_ID IN (SELECT REQUEST_ID
                          FROM   CORP_CC2_MIGRATE_BUREAU_DATA
                          WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from REQUEST table.') ;

    DELETE FROM CREDIT_CHECK_REQUEST
    WHERE  REQUEST_ID IN (SELECT REQUEST_ID
                          FROM   CORP_CC2_MIGRATE_BUREAU_DATA
                          WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from CREDIT_CHECK_REQUEST table.') ;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE CORP_CC2_MIGRATE_BUREAU_DATA' ;

    -- COMMIT ;
    dbms_output.put_line ('No commit was issued. Please check results before committing the DB.') ;

END sp_migrate_iav_bureau_delete ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to migrate security deposits from Excel
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_security_deposits
IS

-- Declarations
-- Cursors
CURSOR C1 IS -- All deposits which have not yet been migrated
       SELECT a.*
       FROM   CORP_CC2_MIGRATE_SEC_DEP_STG a
       WHERE  ICE_REFERENCE IS NOT NULL 
              AND NOT EXISTS (SELECT NULL
                              FROM   CORP_CC2_MIGRATE_SEC_DEP b
                              WHERE  b.ICE_CUSTOMER_ID = a.ICE_REFERENCE)
       ORDER BY ICE_REFERENCE ASC, NVL (DEPOSIT_AMOUNT_REQUIRED, -1) DESC ;

-- Local variables
v_entity_id     ENTITY.ENTITY_ID%TYPE ;
v_ici           ENTITY_RELATIONSHIP.ICE_CUSTOMER_ID%TYPE ;
v_this_ice_ref  ENTITY_RELATIONSHIP.ICE_CUSTOMER_ID%TYPE ;
v_sqlerrm       VARCHAR2 (4000) ; -- Composite (code + msg) error message
v_ccd_seq       NUMBER ;
v_dep_req       NUMBER ;
v_ent_exists    NUMBER ;

-- Counters
v_cnt           PLS_INTEGER := 0 ;
v_ok            PLS_INTEGER := 0 ;
v_error         PLS_INTEGER := 0 ;

BEGIN

    v_this_ice_ref := -999 ;
    FOR c1_rec IN C1 LOOP
        v_cnt := v_cnt + 1 ;
        v_ici := c1_rec.ice_reference ; -- Save ICE ref
        
        IF v_ici <> v_this_ice_ref THEN -- Update, when an ICE_CUSTOMER_ID is done (i.e. new one came in)
            IF v_this_ice_ref <> -999 THEN -- Except for the first dummy one...
                UPDATE COMPANY_CAPITAL a
                       SET a.TOTAL_HOLDING = (SELECT SUM (AMOUNT_HELD) AS TOTAL_HOLDING
                                              FROM   COMPANY_CAPITAL_DETAIL
                                              WHERE  ENTITY_ID = v_entity_id)
                WHERE  ENTITY_ID = v_entity_id ;

                -- Update migration audit/helper table with known entity id
                UPDATE CORP_CC2_MIGRATE_SEC_DEP
                       SET ENTITY_ID = v_entity_id,
                           STATUS      = 'OK',
                           MESSAGE     = 'Migrated successfully'
                WHERE  ICE_CUSTOMER_ID = v_this_ice_ref
                       AND STATUS IS NULL ; -- Not errored when processing detail

                COMMIT ;
                
            END IF ;

            -- Register in migration helper/audit table
            INSERT INTO CORP_CC2_MIGRATE_SEC_DEP (ICE_CUSTOMER_ID, ENTITY_ID, 
                                                  STATUS, MESSAGE, CREATED_DATE)
                                                  VALUES (v_ici, NULL, 
                                                          NULL, NULL, SYSDATE) ; -- Audit table


            v_this_ice_ref := v_ici ;
            v_dep_req := c1_rec.deposit_amount_required ; -- Take first deposit amount required

            -- Lookup entity
            SELECT MAX (ENTITY_ID) INTO v_entity_id
            FROM   ENTITY_RELATIONSHIP
            WHERE  ENTITY_ROLE_ID = 2 -- Customer
                   AND ICE_CUSTOMER_ID = v_ici ;

        END IF ;
  
        BEGIN -- Block needed for error handling
      
            -- Could not find entity
            IF v_entity_id IS NULL THEN
                UPDATE CORP_CC2_MIGRATE_SEC_DEP
                       SET STATUS  = 'ERROR',
                       MESSAGE = 'Could not find entity based on ICE Customer id: ' || v_ici
                WHERE  ICE_CUSTOMER_ID = v_ici ;
                
                v_error := v_error + 1 ;
                
            ELSE
                
                -- Get next sequnce number for company capital detail       
                SELECT COMPANY_CAPITAL_DETAIL_SQ.NEXTVAL INTO v_ccd_seq
                FROM DUAL ;

                -- Check if summary row exists
                SELECT COUNT (*) INTO v_ent_exists
                FROM   COMPANY_CAPITAL
                WHERE  ENTITY_ID = v_entity_id ;

                IF v_ent_exists = 0 THEN
                    INSERT INTO COMPANY_CAPITAL -- Maintain summary (parent table) first
                           (entity_id, capital_type, total_capital_required, total_holding,
                           finance_reference, comments)
                           VALUES (v_entity_id, 'D', v_dep_req, NULL,
                                   NULL, 'Migration') ;
                END IF ;
                
                -- Populate detail
                INSERT INTO COMPANY_CAPITAL_DETAIL
                       (capital_entry_det_id, entity_id, capital_type, 
                        amount_recieved, amount_held, date_recieved,
                        date_ft_to_holding, guarantee_expiry_date, comments)
                       VALUES (v_ccd_seq, v_entity_id, 'D', 
                               c1_rec.deposit_amount_received, c1_rec.deposit_amount_received, c1_rec.security_received_date,
                               c1_rec.date_transferred, NULL, 'Migration') ;
                                                        
                v_ok := v_ok + 1 ;
            END IF ;
                          
            -- Exception handler            
            EXCEPTION
                WHEN OTHERS THEN

                    v_sqlerrm := SUBSTR (SQLCODE || ': ' || SQLERRM, 1, 4000) ;
                    ROLLBACK ;

                    -- Register error in audit table
                    UPDATE CORP_CC2_MIGRATE_SEC_DEP
                           SET STATUS  = 'ERROR',
                               MESSAGE = v_sqlerrm || ' ICE Customer id: ' || v_ici
                    WHERE  ICE_CUSTOMER_ID  = v_ici ;

                    COMMIT ;
                    v_error := v_error + 1 ;
    
        END ;
    
    END LOOP ;

    -- Last one after loop terminates
    UPDATE COMPANY_CAPITAL a
           SET a.TOTAL_HOLDING = (SELECT SUM (AMOUNT_HELD) AS TOTAL_HOLDING
                                  FROM   COMPANY_CAPITAL_DETAIL
                                  WHERE  ENTITY_ID = v_entity_id)
    WHERE  ENTITY_ID = v_entity_id ;

    COMMIT ;

    -- Final stats
    dbms_output.put_line ('Number of rows in staging table                  : ' || v_cnt) ;
    dbms_output.put_line ('Number of rows migrated successfully             : ' || v_ok) ;
    dbms_output.put_line ('Number of rows failed migration                  : ' || v_error) ;

    -- Exception handler
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK ;
            RAISE ;

END sp_migrate_security_deposits ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to delete migrated security deposits
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_sec_dep_delete
IS

BEGIN

    -- Delete company capital data
    DELETE FROM COMPANY_CAPITAL_DETAIL
    WHERE  ENTITY_ID IN (SELECT ENTITY_ID
                         FROM   CORP_CC2_MIGRATE_SEC_DEP
                         WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from COMPANY_CAPITAL_DETAIL table.') ;

    DELETE FROM COMPANY_CAPITAL
    WHERE  ENTITY_ID IN (SELECT ENTITY_ID
                         FROM   CORP_CC2_MIGRATE_SEC_DEP
                         WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from COMPANY_CAPITAL table.') ;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE CORP_CC2_MIGRATE_SEC_DEP' ;

    -- COMMIT ;
    dbms_output.put_line ('No commit was issued. Please check results before committing the DB.') ;

END sp_migrate_sec_dep_delete ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to migrate guarantees from Excel
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_guarantees
IS

-- Declarations
-- Cursors
CURSOR C1 IS -- All deposits which have not yet been migrated
       SELECT a.*
       FROM   CORP_CC2_MIGRATE_GTEES_STG a
       WHERE  TRACKER_ID IS NOT NULL 
              AND NOT EXISTS (SELECT NULL
                              FROM   CORP_CC2_MIGRATE_GTEES b
                              WHERE  b.TRACKER_ID = a.TRACKER_ID)
       ORDER BY TRACKER_ID ASC ;

-- Local variables
v_entity_id     ENTITY.ENTITY_ID%TYPE ;
v_tracker_id    CREDIT_CHECK_REQUEST.REQUEST_ID%TYPE ;
v_this_tr_id    CREDIT_CHECK_REQUEST.REQUEST_ID%TYPE ;
v_sqlerrm       VARCHAR2 (4000) ; -- Composite (code + msg) error message
v_ccd_seq       NUMBER ;
v_gtee_req      NUMBER ;
v_ent_exists    NUMBER ;

-- Counters
v_cnt           PLS_INTEGER := 0 ;
v_ok            PLS_INTEGER := 0 ;
v_error         PLS_INTEGER := 0 ;

BEGIN

    v_this_tr_id := -999 ;
    FOR c1_rec IN C1 LOOP
        v_cnt := v_cnt + 1 ;
        v_tracker_id := c1_rec.tracker_id ; -- Save ICE ref
        
        IF v_tracker_id <> v_this_tr_id THEN -- Update, when a TRACKER_ID is done (i.e. new one came in)
            IF v_this_tr_id <> -999 THEN -- Except for the first dummy one...               
                UPDATE COMPANY_CAPITAL a
                       SET a.TOTAL_HOLDING = (SELECT SUM (AMOUNT_HELD) AS TOTAL_HOLDING
                                              FROM   COMPANY_CAPITAL_DETAIL
                                              WHERE  ENTITY_ID = v_entity_id)
                WHERE  ENTITY_ID = v_entity_id ;

                -- Update migration audit/helper table with known entity id
                UPDATE CORP_CC2_MIGRATE_GTEES
                       SET ENTITY_ID = v_entity_id,
                           STATUS      = 'OK',
                           MESSAGE     = 'Migrated successfully'
                WHERE  TRACKER_ID = v_this_tr_id
                       AND STATUS IS NULL ; -- Not errored when processing detail

                COMMIT ;
                
            END IF ;

            -- Register in migration helper/audit table
            INSERT INTO CORP_CC2_MIGRATE_GTEES (TRACKER_ID, ENTITY_ID, 
                                                STATUS, MESSAGE, CREATED_DATE)
                                                VALUES (v_tracker_id, NULL, 
                                                        NULL, NULL, SYSDATE) ; -- Audit table


            v_this_tr_id := v_tracker_id ;
            v_gtee_req := c1_rec.gtee_amount_required ;

            -- Lookup entity
            SELECT MAX (ENTITY_ID) INTO v_entity_id
            FROM   CREDIT_CHECK_REQUEST
            WHERE  REQUEST_ID = v_tracker_id ;

        END IF ;
  
        BEGIN -- Block needed for error handling
      
            -- Could not find entity
            IF v_entity_id IS NULL THEN
                UPDATE CORP_CC2_MIGRATE_GTEES
                       SET STATUS  = 'ERROR',
                       MESSAGE = 'Could not find entity based on Tracker id: ' || v_tracker_id
                WHERE  TRACKER_ID = v_tracker_id ;
                
                v_error := v_error + 1 ;
                
            ELSE
                
                -- Get next sequence number for company capital detail       
                SELECT COMPANY_CAPITAL_DETAIL_SQ.NEXTVAL INTO v_ccd_seq
                FROM DUAL ;

                -- Check if summary row exists
                SELECT COUNT (*) INTO v_ent_exists
                FROM   COMPANY_CAPITAL
                WHERE  ENTITY_ID = v_entity_id ;

                IF v_ent_exists = 0 THEN
                    INSERT INTO COMPANY_CAPITAL -- Maintain summary (parent table) first
                           (entity_id, capital_type, total_capital_required, total_holding,
                           finance_reference, comments)
                           VALUES (v_entity_id, 'G', v_gtee_req, NULL,
                                   NULL, 'Migration') ;
                END IF ;
                
                -- Populate detail
                INSERT INTO COMPANY_CAPITAL_DETAIL
                       (capital_entry_det_id, entity_id, capital_type, 
                        amount_recieved, amount_held, date_recieved,
                        date_ft_to_holding, guarantee_expiry_date, comments)
                       VALUES (v_ccd_seq, v_entity_id, 'G', 
                               c1_rec.gtee_amount_received, c1_rec.gtee_amount_received, c1_rec.security_received_date,
                               NULL, NULL, c1_rec.comments) ;
                                                        
                v_ok := v_ok + 1 ;
            END IF ;
                          
            -- Exception handler            
            EXCEPTION
                WHEN OTHERS THEN

                    v_sqlerrm := SUBSTR (SQLCODE || ': ' || SQLERRM, 1, 4000) ;
                    ROLLBACK ;

                    -- Register error in audit table
                    UPDATE CORP_CC2_MIGRATE_GTEES
                           SET STATUS  = 'ERROR',
                               MESSAGE = v_sqlerrm || ' Tracker id: ' || v_tracker_id
                    WHERE  TRACKER_ID  = v_tracker_id ;

                    COMMIT ;
                    v_error := v_error + 1 ;
    
        END ;
    
    END LOOP ;

    -- Last one after loop terminates
    UPDATE COMPANY_CAPITAL a
           SET a.TOTAL_HOLDING = (SELECT SUM (AMOUNT_HELD) AS TOTAL_HOLDING
                                  FROM   COMPANY_CAPITAL_DETAIL
                                  WHERE  ENTITY_ID = v_entity_id)
    WHERE  ENTITY_ID = v_entity_id ;

    COMMIT ;

    -- Final stats
    dbms_output.put_line ('Number of rows in staging table                  : ' || v_cnt) ;
    dbms_output.put_line ('Number of rows migrated successfully             : ' || v_ok) ;
    dbms_output.put_line ('Number of rows failed migration                  : ' || v_error) ;

    -- Exception handler
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK ;
            RAISE ;

END sp_migrate_guarantees ;

----------------------------------------------------------------------------------------------------------------------------------------------
--
-- Procedure to delete migrated guarantees
--
----------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE sp_migrate_gtees_delete
IS

BEGIN

    -- Delete company capital data
    DELETE FROM COMPANY_CAPITAL_DETAIL
    WHERE  ENTITY_ID IN (SELECT ENTITY_ID
                         FROM   CORP_CC2_MIGRATE_GTEES
                         WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from COMPANY_CAPITAL_DETAIL table.') ;

    DELETE FROM COMPANY_CAPITAL
    WHERE  ENTITY_ID IN (SELECT ENTITY_ID
                         FROM   CORP_CC2_MIGRATE_GTEES
                         WHERE  STATUS = 'OK') ;
    dbms_output.put_line ('Deleted ' || SQL%ROWCOUNT || ' row(s) from COMPANY_CAPITAL table.') ;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE CORP_CC2_MIGRATE_GTEES' ;

    COMMIT ;

END sp_migrate_gtees_delete ;

END pkg_corp_cc2_migration ;
