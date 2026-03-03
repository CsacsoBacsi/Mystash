#!/bin/ksh
#*****************************************************************************
#*                                                                           *
#* Usage       : ksh ./gmdftr005ub01.ksh JOBNAME                             *
#*                                                                           *
#* System      : GMA 2                                                       *
#* Subsystem   : SFTP Elec and gas short/long term costs files               *
#*                                                                           *
#* Module Desc : This script sftp-s files from a Windows G drive             *
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
#* 08/11/2011 Csaba Riedlinger 1.0  Initial Version based on bsdadhocgas.ksh *
#*                                  by Bradnam                               *
#*****************************************************************************

. ${RLF_PROFILE}/ut_functions.ksh

set +x # Debug off
ut_journal "$MOD" "Starting..." # $MOD set by ut_functions.ksh to JOBNAME passed to Control-M

TEMPFOLDER=/tmp/gma_sftp$$
TEMPFILE=/tmp/gma_sftp$$.txt
FILEMASK="*.*"
MACHINE="fame.e-ssi.net"

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
       ut_journal ${MOD} "Error getting SFTP file list from GMA.GMA_T_FILE_TRANSFER_CONFIG";
       tidy_up;
       ut_leave 1;
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
       ut_journal ${MOD} "Error getting SFTP file config details from GMA.GMA_T_FILE_TRANSFER_CONFIG";
       tidy_up;
       ut_leave 1;
   fi

   # Split the pipe-delimited value into it's parts
   OLDIFS=$IFS
   IFS='|'
   set -A details $RETVAL
   IFS=$OLDIFS

   SOURCE_LOCATION=${details[0]}
   TARGET_LOCATION=${details[1]}
   PROCESSED_LOCATION=${details[2]}

   # Remove unwanted char (CR) from the end of the returned string
   PROCESSED_LOCATION=$(echo ${PROCESSED_LOCATION})
}

get_list() {
    #-------------------------------------------------------------------
    # Get a list of files to transfer - we will process them 1 at a time (so we don't
    # inadvertantly delete files that may arrive during the running of the script
    #-------------------------------------------------------------------
    /usr/local/bin/perl -I ${RLF_PERL} ${RLF_PERL}/sftp.pl -v << EOF
    open ${MACHINE}
    cd ${SOURCE_LOCATION}
    lcd ${TEMPFOLDER}
    ls ${FILEMASK} ${TEMPFILE}
    bye
EOF
    check_ftp
}

get_ftp() {
    #-------------------------------------------------------------------
    # Sftp get a single file
    #-------------------------------------------------------------------
    wanted_file=${1}
    /usr/local/bin/perl -I ${RLF_PERL} ${RLF_PERL}/sftp.pl -v << EOF
    open ${MACHINE}
    cd ${SOURCE_LOCATION}
    lcd ${TEMPFOLDER}
    get ${wanted_file}
    bye
EOF
    check_ftp
}

rename_ftp() {
    #-------------------------------------------------------------------
    # Move a remote file (from the source directory to the processed)
    #-------------------------------------------------------------------
    wanted_file=${1}
    this_date=`date +%Y%m%d_%H%M%S`
    # Suffix processed (sftp-ed) file with current date and time
    /usr/local/bin/perl -I ${RLF_PERL} ${RLF_PERL}/sftp.pl -v << EOF
    open ${MACHINE}
    rename ${SOURCE_LOCATION}/${wanted_file} ${PROCESSED_LOCATION}/${wanted_file}.${this_date}
    bye
EOF
    check_ftp
}

check_ftp() {
    #-------------------------------------------------------------------
    # Parse log file for error messages
    #-------------------------------------------------------------------
    FTPERRCNT=$(egrep '^[4|5][0-9][0-9]' ${KSHLOG} | \
                egrep -v 'rows|bytes'       | \
                wc -l)
    [ ${FTPERRCNT} -eq 0 ] || {
        ut_shell_event $LINENO "1" "FTP issue - please check logs - Series 400/500 Error msg issued";
        tidy_up;
        ut_leave 1;
    }
}

tidy_up() {
    #-------------------------------------------------------------------
    # Remove temp files and directories
    #-------------------------------------------------------------------
    if [ -d ${TEMPFOLDER} ]
    then
        ut_journal "${MOD}" "Tidy Up - Removing Temp Folder ${TEMPFOLDER}"
        rm -rf ${TEMPFOLDER}
        if [ $? -ne 0 ]
        then
            ut_shell_event $LINENO "1" "Failed to remove ${TEMPFOLDER} - exiting";
            ut_leave 1;
        fi
    fi

    if [ -f ${TEMPFILE} ]
    then
        ut_journal "${MOD}" "Tidy Up - Removing Temp Log ${TEMPFILE}"
        rm -f ${TEMPFILE}
        if [ $? -ne 0 ]
        then
            ut_shell_event $LINENO "1" "Failed to remove ${TEMPFILE} - exiting";
            ut_leave 1;
        fi
    fi
}

#----------------------------------------------------------------------------------------------------------------
#************************************************ M A I N *******************************************************
#----------------------------------------------------------------------------------------------------------------

# APP_PERL will be set sometime in the future, for now, we set it to RLF_PERL
export APP_PERL=$RLF_PERL

ut_journal "${MOD}" "Checking/Making temp folder $TEMPFOLDER";
if [ ! -d ${TEMPFOLDER} ]
then
    mkdir ${TEMPFOLDER}
    if [ $? -ne 0 ]
    then
        ut_shell_event $LINENO "1" "Unable to create ${TEMPFOLDER}";
        ut_leave 1
    fi
fi

ut_journal "${MOD}" "Getting a list of expected files from the config table";
get_file_list

if [ ! ${#filelist[@]} -gt 0 ]
then
    ut_shell_event $LINENO "1" "No files found in file transfer config table, exiting script";
    tidy_up;
    ut_leave 0;
fi

# For each file in config table
for this_file in ${filelist[@]}
do
    # Get file transfer detail
    get_file_transfer_detail ${this_file}

    # Get list of files in source location of this file
    get_list

    # Check if any files available in source folder
    files_found=$( cat ${TEMPFILE} | wc -l )
    if [ ! ${files_found} -gt 0 ]
    then
        continue
    fi

    # Check if this file is in the list of available files
    file_found=
    while read filename
    do
        if [[ $filename = $this_file ]]
        then
            file_found=1
        fi
    done < ${TEMPFILE}

    # If file found, FTP it then move it to processed dir (on source server) and move it to target location (on target server)
    if [ $file_found ]
    then

        ut_journal "${MOD}" "SFTP-ing file from source location to target machine's temp directory"
        get_ftp ${this_file}
        ut_journal "${MOD}" "We have ftp'ed ${this_file} to $TEMPFOLDER"

        ut_journal "${MOD}" "Moving ${this_file} from ${SOURCE_LOCATION} to ${PROCESSED_LOCATION}"
        rename_ftp ${this_file}
        ut_journal "${MOD}" "File ${this_file} has been moved to processed folder"

        ut_journal "${MOD}" "Moving the file to its target folder ${TARGET_LOCATION} from the temp folder"
        mv ${TEMPFOLDER}/${this_file} ${TARGET_LOCATION}/${filename}
        if [ $? -ne 0 ]
        then
            ut_shell_event $LINENO "1" "Failed to move ${TEMPFOLDER}/${this_file} - exiting";
            tidy_up;
            ut_leave 1;
        else
            ut_journal "${MOD}" "Moved ${TEMPFOLDER}/${this_file} to target location ${TARGET_LOCATION}"
        fi
    fi
done

tidy_up
ut_journal "${MOD}" "Job Ended OK"
ut_leave 0

