#!/bin/ksh
#*****************************************************************************
#*                                                                           *
#* Usage       : ksh ./gmdftr005ub01.ksh JOBNAME                             *
#*                                                                           *
#* System      : GMA 2                                                       *
#* Subsystem   : Elec and gas short/long term costs files                    *
#*                                                                           *
#* Module Desc : This script deletes files from a designated directory       *
#*                                                                           *
#* Type        : Unix Korn Shell script                                      *
#*                                                                           *
#* Parameters  : Control-M jobname (for PAL)                                 *
#*                                                                           *
#* Returns     : 1  = Failure                                                *
#*               0  = Success                                                *
#*                                                                           *
#* History Log                                                               *
#* #==========================================================================
#* 08/11/2011 Csaba Riedlinger 1.0  Initial Version                          *
#*****************************************************************************

. ${RLF_PROFILE}/ut_functions.ksh

set +x # Debug off
ut_journal "$MOD" "Starting..." # $MOD set by ut_functions.ksh to JOBNAME passed to Control-M

FILEMASK="*.*"

#----------------------------------------------------------------------------------------------------------------
#******************************************* S U B R O U T I N E S **********************************************
#----------------------------------------------------------------------------------------------------------------

get_file_list () {
   #-------------------------------------------------------------------
   # Get a list of files from file transfer config table
   #-------------------------------------------------------------------
   ut_get_sql_value RETVAL "SELECT gma.fn_get_file_transfer_files FROM dual" "set lines 1000"
   SQL_RC=$?
   if [[ $SQL_RC -ne 0 ]]
   then
       ut_journal ${MOD} "Error getting SFTP file list from GMA.GMA_T_FILE_TRANSFER_CONFIG"
       tidy_up
       ut_leave 1
   fi

   # Split the pipe-delimited value into it's parts
   OLDIFS=$IFS
   IFS='|'
   set -A filelist $RETVAL
   IFS=$OLDIFS
}

get_file_transfer_detail () {
   #-------------------------------------------------------------------
   # Get file transfer detail for a particular file
   #-------------------------------------------------------------------
   ut_get_sql_value RETVAL "SELECT gma.fn_get_file_transfer_details ('${1}') FROM dual" "set lines 1000"
   SQL_RC=$?
   if [[ $SQL_RC -ne 0 ]]
   then
       ut_journal ${MOD} "Error getting SFTP file config details from GMA.GMA_T_FILE_TRANSFER_CONFIG"
       tidy_up
       ut_leave 1
   fi

   # Split the pipe-delimited value into it's parts
   OLDIFS=$IFS
   IFS='|'
   set -A details $RETVAL
   IFS=$OLDIFS

   SOURCE_LOCATION=${details[0]}
   TARGET_LOCATION=${details[1]}
   PROCESSED_LOCATION=${details[2]}

   PROCESSED_LOCATION=$(echo ${PROCESSED_LOCATION})
}

#----------------------------------------------------------------------------------------------------------------
#************************************************ M A I N *******************************************************
#----------------------------------------------------------------------------------------------------------------

# APP_PERL will be set sometime in the future, for now, we set it to RLF_PERL
export APP_PERL=$RLF_PERL

ut_journal "${MOD}" "Getting a list of expected files from the config table";
get_file_list

if [ ! ${#filelist[@]} -gt 0 ]
then
    ut_shell_event $LINENO "1" "No files found in file transfer config table, exiting script"
    ut_leave 0
fi

# For each file in config table
for this_file in ${filelist[@]}
do
    # Get file transfer detail
    get_file_transfer_detail ${this_file}

    # Check if file exists in target location
    if [ -e ${TARGET_LOCATION}/${this_file} ]
    then
        ut_journal "${MOD}" "Trying to delete file ${this_file} from ${TARGET_LOCATION}"
        rm -f ${TARGET_LOCATION}/${this_file}
        if [ $? -ne 0 ]
        then
            ut_journal "${MOD}" "File ${this_file} could not be deleted";
        else
            ut_journal "${MOD}" "File ${this_file} has been deleted";
        fi
    else
        ut_journal "${MOD}" "File ${this_file} does not exist";
    fi
done

ut_journal "${MOD}" "Job Ended OK"
ut_leave 0

