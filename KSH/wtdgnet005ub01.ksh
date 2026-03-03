#!/bin/ksh
#*******************************************************************************
# Copyright (c) 2011 E-On plc                                                  *
#*******************************************************************************
#* Usage : ksh ./wtdgnet005ub01.ksh 1                                          *
#*               (weather daily get noon effective temp 005 unix batch 01)     *
#* Parameters  : None                                                          *
#*                                                                             *
#* System      : WEATHER                                                       *
#*                                                                             *
#* Returns     : 1 = Failure                                                   *
#*             : 0 = Success                                                   *
#*                                                                             *
#* Description : Calls a package procedure to fetch noon effective temperature *
#*               per GSP from the Settlments db                                *
#*                                                                             *
#*******************************************************************************
#*                M O D I F I C A T I O N S   L O G                            *
#*******************************************************************************
#* Date      Author             Version   Description                          *
#* --------- ------------------ --------- ------------------------------------ *
#* 25 Jul 11 Csaba Riedlinger   1.0       Initial Version                      *
#*                                                                             *
#*******************************************************************************

# was . ${ICE_PROFILE}/ut_functions.ksh
. ${WET_PROFILE}/ut_functions.ksh

ut_run_spu "wet_data.pkg_d0018.import_d0018"
ut_exit_nonzero_rc $LINENO "Problem with calling stored procedure" "Calling pkg_d0018.import_d0018"

ut_leave 0
