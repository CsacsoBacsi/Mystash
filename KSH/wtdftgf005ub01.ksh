#!/bin/ksh
#*******************************************************************************
#* Copyright (c) 2003 PowerGen plc                                             *
#*******************************************************************************
#* System      : Weather                                                       *
#*                                                                             *
#* Sub-System  : File transfer                                                 *
#*                                                                             *
#* Description : Batch process to poll for MetOffice files on the DMZ server.  *
#*                                                                             *
#*******************************************************************************
#*                M O D I F I C A T I O N S   L O G                            *
#*******************************************************************************
#* Date          Author          Vers    Description                           *
#* -----------   ---------------         ------------------------------------  *
#* 10/10/10      David Reid      1.0     Initial Release                       *
#* 13/05/11      C. Riedlinger   1.1     Changed FTP transfer mode to BIN      *
#* 23/05/11      C. Riedlinger   1.2     Added loop and sleep                  *
#* 20/07/11      C. Riedlinger   1.3     Added double quotes around file names *
#*                                       to handle files with spaces           *
#*******************************************************************************

. ${WET_PROFILE}/ut_functions.ksh

ut_journal "${MOD}" "*** JOB COMMENCED ***"

# Set local envars
typeset -i RC=0
REMOTE_FILE_LIST=${WET_DATA_TMP}/$(basename $0 ksh)$$.filelist
REMOTE_FILE_MASK=*
PROVIDER=METOFFICE
INPUT_NAME=MAIN_INBOX


ftp_list()
{
ftp -iv <<END 
open ${REMOTE_SERVER}
cd ${REMOTE_DIR}
nlist ${REMOTE_FILE_MASK} ${REMOTE_FILE_LIST} 
END
#ut_chk_ftp
#ut_exit_nonzero_rc $LINENO "Errors encountered" "Getting a list of files to FTP (nlist)"        
# Above line causes 'No files found' to be treated as an error and exits. Don't want to do that.
}

ftp_get()
{
ftp -iv <<END 
open ${REMOTE_SERVER}
lcd ${LOCAL_FT_BUILD}
cd ${REMOTE_DIR}
bin
get $1 ${LOCAL_FT_BUILD}/$1 
!mv ${LOCAL_FT_BUILD}/$1 ${LOCAL_FT_IN}/$1
END
ut_chk_ftp
ut_exit_nonzero_rc $LINENO "Errors encountered" "Getting file $1"
}

ftp_delete()
{
ftp -iv <<END 
open ${REMOTE_SERVER}
cd ${REMOTE_DIR}
delete $1
END
ut_chk_ftp
ut_exit_nonzero_rc $LINENO "Errors encountered" "Deleting remote file $1"
}

counter=0
start_time=$SECONDS

# Loop for 58 mins. Wake up every minute.
while [[ $counter ]]
do

#-------------------------------------------------------------------
# Get FTP details - remote server, local directory locations etc
#-------------------------------------------------------------------
ut_get_sql_value FTPPARAMS "SELECT wet_cnf.pkg_wet_utility.fn_get_input_system_details('$PROVIDER', '$INPUT_NAME') FROM dual"
ut_exit_nonzero_rc $LINENO "Errors encountered" "Obtaining the remote system parameters from WET_CNF.INPUT_SYSTEM"


#-------------------------------------------------------------------
# Split the pipe-delimited value into it's parts
#-------------------------------------------------------------------
OLDIFS=$IFS
IFS='|'
set -A params $FTPPARAMS
IFS=$OLDIFS


#-------------------------------------------------------------------
# assign database value returned to envars. eval is to handle 
# the database returning the name of an envar.
#-------------------------------------------------------------------
REMOTE_SERVER=${params[0]}
REMOTE_DIR=${params[1]}
eval LOCAL_FT_BUILD=${params[2]}
eval LOCAL_FT_IN=${params[3]}

ut_journal ${MOD} "Remote machine is $REMOTE_SERVER"
ut_journal ${MOD} "Remote directory is $REMOTE_DIR"
ut_journal ${MOD} "Local Build is $LOCAL_FT_BUILD"
ut_journal ${MOD} "Local Target is $LOCAL_FT_IN"


#---------------------------------------------------------------------------
# Test values returned (all mandatory fields in db so just check first one)
#---------------------------------------------------------------------------
if [[ -z ${REMOTE_SERVER} ]] 
then
    ut_journal ${MOD} "Error - the target machine envar (REMOTE_SERVER) is empty"
    ut_shell_event ${LINENO} 1 "Error - the target machine envar (REMOTE_SERVER) is empty"
    ut_leave 2
fi

#-----------------------------------------------------------------
# Get a list of any files waiting on remote server
#-----------------------------------------------------------------
ftp_list


#-----------------------------------------------------------------
# If there are any, fetch 'em then delete 'em 
# Cope with the possibility that the data providers may be 
# FTPing files with a .build* or .transfer* suffix and then
# renaming them.
#-----------------------------------------------------------------
if [[ -s $REMOTE_FILE_LIST ]]
then
   cat $REMOTE_FILE_LIST | grep -v '.build' | grep -v '.transfer' |
   while read file
   do
      filename="\"$file\""
      ftp_get $filename
      ftp_delete $filename
   done
else 
    ut_journal ${MOD} "No files on $REMOTE_SERVER to get"
fi

counter=$(($counter+1))
((elapsed=SECONDS-start_time))

if [[ $elapsed -gt 3480 ]]
then
    break
fi

# Sleep for a minute
sleep 60 

done

ut_leave 0
