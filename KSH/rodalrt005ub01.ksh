#!/bin/ksh
#******************************************************************************
#*                                                                            *
#* Usage       : ksh ./RODALRT005UB01.ksh 		                      *
#* System      : RNG                                                          *
#* Returns     : 0 = Success                                                  *
#*               != 0 Error                                                   *
#* Description : This script calls riskngov.pkg_rng_alerts.sp_process_items   *
#*		 to create alerts and send emails to the relevant people      * 
#******************************************************************************
#*                      M O D I F I C A T I O N  L O G                        *
#******************************************************************************
#* Date      Author               Version  Description                        *
#* --------- ------------------   -------  ---------------------------------- *
#* 29 Dec 11 S. Chatterjee         1.0     Initial                            *
#******************************************************************************

. /${ROUTE_PROFILE}/ut_functions.ksh

ut_run_spu "RISKNGOV.PKG_RNG_ALERTS.SP_PROCESS_ITEMS"
ut_exit_nonzero_rc ${LINENO} "Error issued by ut_run_spu" "Running PKG_RNG_ALERTS.SP_PROCESS_ITEMS"

ut_leave 0
