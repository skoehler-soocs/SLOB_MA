#!/bin/bash

# This file is a part of SLOB - The Simple Database I/O Testing Toolkit for Oracle Database
#
# Copyright (c) 1999-2017 Kevin Closson and Kevin Closson d.b.a. Peak Performance Systems
#
# The Software
# ------------
# SLOB is a collection of software, configuration files and documentation (the "Software").
#
# Use
# ---
# Permission is hereby granted, free of charge, to any person obtaining a copy of the Software, to
# use the Software. The term "use" is defined as copying, viewing, modifying, executing and disclosing
# information about use of the Software to third parties.
#
# Redistribution
# --------------
# Permission to redistribute the Software to third parties is not granted. The Software           
# is obtainable from kevinclosson.net/slob. Any redistribution of the Software to third parties
# requires express written permission from Kevin Closson.
#
# The copyright notices and permission notices shall remain in all copies of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.

function f_msg() {
local msgtype="$1"
local msgtxt="$2"
local now=$(date +"%Y.%m.%d-%H:%M:%S")
local type=$( echo $msgtype | awk '{ printf("%-7s\n",$1) }')

echo "${type} : ${now} : ${msgtxt}"

return 0
}

function f_is_int() {
local s="$1"

if ( ! echo "$s" |  grep -q "^-\?[0-9]*$" ) 
then
	return 1
else
	return 0
fi

return 0
}

function f_myexit(){
#global SLOB_TEMPDIR
local myreturn="$1"

if [ "$myreturn" -ne 0 ]
then
	f_msg FATAL "Aborting execution. Cleaning up SLOB temporary directory (${SLOB_TEMPDIR})."
else
	f_msg NOTIFY "Cleaning up SLOB temporary directory (${SLOB_TEMPDIR})."
fi

f_myrm "$SLOB_TEMPDIR"
f_kill_misc_pids

exit $myreturn
}

function f_validate_database_statistics_type() {
local stats_type="$1"

if [[ "$stats_type" != "statspack" && "$stats_type" != "awr" ]]
then
	f_msg FATAL ">>>${stats_type}<<< is not a supported value for slob.conf->DATABASE_STATISTICS_TYPE. Abort"
	return 1
fi

return 0
}

function f_clean_old_files() {
local files=`echo $*`

f_msg NOTIFY "Clearing temporary SLOB output files from previous SLOB testing."

if ( ! f_myrm  "$files" )
then
	f_msg FATAL "Failed to remove prior SLOB test files ( \"$files\")."
	return 1
fi

return 0
}

function f_execute_external_script() {
#global WORKDIR
local myscript="$1"
local call_arg="$2"

# The only failure case is the script is defined in slob.conf but is not executable.

[[ -z "$myscript" ]] && return 0

if [ ! -x "$myscript" ]
then
	f_msg FATAL "The SLOB external script defined in slob.conf ($myscript) is not executable. Abort."
	return 1
else
	f_msg NOTIFY "Executing external script defined in slob.conf ($myscript). Invocation is: \"sh $myscript $call_arg\" "
	( sh $myscript "$call_arg" > ${myscript}.out 2>&1  ) &
fi

return 0
}

function f_kill_misc_pids(){
#global MISC_PIDS
/bin/kill -9 $MISC_PIDS > /dev/null 2>&1

return 0
}

function f_myrm(){
#global FILE_OPERATIONS_AUDIT_TRAIL_FILE
local argstring=`echo $*`
local flag=""

if [ ! -w "$FILE_OPERATIONS_AUDIT_TRAIL_FILE" ]
then
	f_msg FATAL "${FUNCNAME}: Logic error. The $FILE_OPERATIONS_AUDIT_TRAIL_FILE audit trail file does not exit."
	f_msg FATAL "${FUNCNAME}: Cannot log file operations to audit trail."
	f_msg FATAL "${FUNCNAME}: Not safe to remove SLOB temporary files in this condition. Files not removed:"
	f_msg FATAL "${FUNCNAME}: ${argstring}"
	return 1
fi

f_msg NOTIFY "Removing ${argstring}" >> ${FILE_OPERATIONS_AUDIT_TRAIL_FILE}

rm -fr $argstring

return 0
}

f_create_tempdir() {
#global FILE_OPERATIONS_AUDIT_TRAIL_FILE
local tmpdir="$1"
local now=$( date +"%Y.%m.%d.%H%M%S" )
local dir=""

if [ ! -d "$tmpdir" ]
then
	f_msg FATAL "Cannot create SLOB temporary directory in \"${tmpdir}\". Directory does not exist. "
	return 1
fi

dir="${tmpdir}/.SLOB.${now}"
f_myrm "$dir"

if ( ! mkdir "$dir" )
then
        f_msg FATAL "Cannot create SLOB temporary directory \"${dir}\"."
        return 1
fi

f_msg NOTIFY "Creating ${dir}" >> ${FILE_OPERATIONS_AUDIT_TRAIL_FILE}
echo "$dir"

return 0
}

function f_create_temp_file() {
#global FILE_OPERATIONS_AUDIT_TRAIL_FILE
local f="$1"
local dir=""

dir=$( dirname "$f" )

if [ ! -d "$dir" ]
then
	f_msg FATAL "Cannot create SLOB temporary file (${f}) because ${dir} is not a directory."
	return 1
fi

if ( ! cat /dev/null > "$f" )
then
	f_msg FATAL "Cannot create SLOB temporary file (${f}) under ${dir}."
	return 1
fi

f_msg NOTIFY "Creating ${f}" >> ${FILE_OPERATIONS_AUDIT_TRAIL_FILE}
return 0
}

function f_test_conn() {
#global SLOB_TEMPDIR
local constring="$*"
local ret=0
local tmpfile="${SLOB_TEMPDIR}/${RANDOM}.${FUNCNAME}.out"

if ( ! f_create_temp_file "$tmpfile" )
then
	f_msg FATAL "${FUNCNAME}: Cannot create temporary file. Abort."
	return 1
fi

f_msg NOTIFY "Testing connectivity. Command: \"sqlplus -L $constring\"."

sqlplus -L "$constring" <<EOF > $tmpfile 2>&1
WHENEVER SQLERROR EXIT 2;
SELECT COUNT(*) FROM DUAL;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "${FUNCNAME}: Instance connectivity check failed. SQL*Plus output: "
	cat $tmpfile
fi

f_myrm "$tmpfile"
return $ret
}

function f_check_for_stragglers() {
#global SLOB_TEMPDIR
local string=""
local tmpfile="${SLOB_TEMPDIR}/${RANDOM}.${FUNCNAME}.out"
local flag="FALSE"
local tmp=""

if ( ! f_create_temp_file "$tmpfile" )
then
        f_msg FATAL "${FUNCNAME}: Cannot create temporary file. Abort."
        return 1
fi

for string in 'iostat -t -xm 3' 'mpstat -P ALL 3' 'vmstat -t 3'
do
	if ( pgrep -f "$string" >> $tmpfile )
	then
		flag=TRUE
	fi
done

if [ "$flag" = "TRUE" ]
then
	f_msg NOTIFY ""
	f_msg NOTIFY ""
	f_msg WARNING "*****************************************************************************"
	f_msg WARNING "SLOB has found possible zombie processes from a prior SLOB test."
	f_msg WARNING "It is possible that a prior SLOB test aborted."
	f_msg WARNING "Please investigate the following processes:"
	f_msg WARNING "*****************************************************************************"
	ps -f `cat $tmpfile`
	f_msg WARNING "*****************************************************************************"

	f_msg NOTIFY "Checking for unlinked output files for processes: `cat $tmpfile | xargs echo`"

	for tmp in `cat $tmpfile`
	do
		f_msg NOTIFY "Unlinked files for process pid ${tmp} (ls -l /proc/${tmp}/fd):"
		ls -l /proc/${tmp}/fd | grep deleted
	done

	f_msg WARNING "*****************************************************************************"
fi

f_myrm "$tmpfile"

return 0
}

function f_check_pct_logic() {
local pct="$1"

[[ "$pct" -lt 0 ]] || [[ "$pct" -gt 100 ]] && return 1
[[ "$pct" -gt 50 ]] && [[ "$pct" -le 99 ]] && return 1

return 0
}

function f_check_hotspot_logic() {
local bsz="$1"
local scale="$2"
local hotspot_mb="$3"
local offset_mb="$4"
local ads_mb=0
local hotspot_zone_mb=0
local x=0

for x in $hotspot_mb $offset_mb
do
	if ( ! f_is_int "$x" )
	then
		f_msg FATAL "Hot Spot tunable paramters in slob.conf must be integer values."
		return 1	
	fi
done

(( ads_mb = $scale * $bsz / 1024 / 1024 ))
(( hotspot_zone_mb = $offset_mb + $hotspot_mb ))

if [ "$hotspot_zone_mb" -gt "$ads_mb" ]
then
	f_msg FATAL "Logic Error: Check slob.conf settings."
	f_msg FATAL ""
	f_msg FATAL "Total SLOB logical block range is ${ads_mb} MB (see slob.conf->SCALE)."
	f_msg FATAL "User specified hotspot offset: ${offset_mb} MB offset (see slob.conf->HOTSPOT_OFFSET_MB)."
	f_msg FATAL "User specified hotspot size ${hotspot_mb} MB (see slob.conf->HOTSPOT_MB)."
	f_msg FATAL "${offset_mb} + ${hotspot_mb} > ${ads_mb}"
	f_msg FATAL "Hotspot extends beyond SLOB logical block range."

	return 1
fi

return 0
}

function f_fix_scale() {
#global MIN_SCALE
local bsz="$1"
local scale="$2"
local factor=""

# Check for permissible values first
factor=$( echo "$scale" | sed 's/[0-9 MGT]//g' )
[[ -n "$factor" ]] && return 1

#Work out scale:
factor=$( echo "$scale" | sed 's/[^MGT]//g' )

if [ -z "$factor" ]
then
        # This is a simple integer assigment case
        scale=$( echo "$scale" | sed 's/[^0-9]//g' )
else
        scale=$( echo "$scale" | sed 's/[^0-9]//g' )
        case "$factor" in
                "M") (( scale = ( 1024 * 1024 * $scale  ) / $bsz ))  ;;
                "G") (( scale = ( 1024 * 1024 * 1024 * $scale  ) / $bsz )) ;;
                "T") (( scale = ( 1024 * 1024 * 1024 * 1024 *  $scale  ) / $bsz )) ;;
                * ) return 1 ;;
        esac
fi

if ( ! f_is_int "$scale" )
then
	f_msg FATAL "${FUNCNAME}: Computed is \"${scale}\". Please report this logic error."
	return 1
fi

if [ "$scale" -lt "$MIN_SCALE" ]
then
	echo $scale
	return 1
else
	echo $scale
	return 0
fi

return 0
}

function f_validate_scale() {
#global SLOB_TEMPDIR
local requested_scale="$1"
local num_schemas="$2"
local user="$3"
local non_admin_connect_string="$4"

local ret=0
local tmpfile="${SLOB_TEMPDIR}/${RANDOM}.${FUNCNAME}.out"

if ( ! f_create_temp_file "$tmpfile" )
then
        f_msg FATAL "${FUNCNAME}: Cannot create temporary file. Abort."
        return 1
fi

sqlplus $user/${user}${non_admin_connect_string} <<EOF 2>/dev/null | sed 's/^.* FATAL/FATAL/g' | grep FATAL > $tmpfile
SET SERVEROUTPUT ON   ;
SET VERIFY OFF;

VARIABLE exit_status NUMBER;

DECLARE

v_requested_test_scale PLS_INTEGER := $requested_scale ;
v_num_schemas PLS_INTEGER := $num_schemas ;

v_sql VARCHAR2(80);
v_rows NUMBER;
v_curr_schema PLS_INTEGER := 1;

BEGIN

:exit_status := 0 ;

FOR v_curr_schema IN 1..v_num_schemas LOOP
	v_sql := 'ALTER SESSION SET CURRENT_SCHEMA = user' || v_curr_schema ;
	EXECUTE IMMEDIATE v_sql;

	SELECT MAX(custid) INTO v_rows FROM CF1;

	IF ( v_requested_test_scale >  v_rows ) THEN

		dbms_output.put_line('FATAL:                       : SLOB schema user' || v_curr_schema || ' has ' || v_rows || ' rows(1 per block).' );
		dbms_output.put_line('FATAL:                       : User specified scale: ' || v_requested_test_scale );
		dbms_output.put_line('FATAL:                       : Cannot test more data than has been loaded.' );

		:exit_status := v_curr_schema;
		EXIT ;
	END IF;
END LOOP;
END;
/

EXIT :exit_status ;
EOF

if ( grep FATAL "$tmpfile" > /dev/null 2>&1 )
then
	f_msg FATAL ""
	f_msg FATAL "Invalid slob.conf setting for SCALE parameter. Error output follows:"
	f_msg FATAL ""
	cat $tmpfile
	f_myrm "$tmpfile"
	return 1
else
	f_myrm "$tmpfile"
	return 0
fi

return 0
}

function f_count_pids() {
local infile="$1"

ps -p `cat $infile` | sed '/PID/d' | wc -l | sed 's/[^0-9]//g'
return 0
}

function f_wait_pids() {
#global SLOB_TEMPDIR
#global debug_outfile
local sessions="$1"
local run_time="$2"
local work_loop="$3"
local pidstring="$4"
local sleeptm=$(( run_time - 0 ))
local tmpfile="${SLOB_TEMPDIR}/${RANDOM}.${FUNCNAME}.out"
local tmp=""
local cnt=0
local monitor_limit=0
local x=0
local sleep_before_first_snoop=10

if ( ! f_create_temp_file "$tmpfile" )
then
        f_msg FATAL "${FUNCNAME}: Cannot create temporary file. Abort."
        return 1
fi

echo "$pidstring" > $tmpfile 2>&1

if [ "$work_loop" -eq 0 ]
then
	# This is a timed run
	f_msg NOTIFY "List of monitored sqlplus PIDs written to ${tmpfile}."

	monitor_limit=300

	sleep $sleep_before_first_snoop

	tmp=`f_count_pids "$tmpfile"`

	if [ "$tmp" -lt "$sessions" ]
	then
		f_msg FATAL ""
		f_msg FATAL ""
		f_msg FATAL "SLOB process monitoring discovered $(( sessions - tmp )) sqlplus processes have aborted."
		f_msg FATAL "Please examine ${debug_outfile}."
		f_msg FATAL ""
		f_msg FATAL "Terminating the remaining SLOB sqlplus processes..."
		kill -15 $pidstring > /dev/null 2>&1
		sleep 1
		kill -15 $pidstring > /dev/null 2>&1
		sleep 1
		kill -9 $pidstring > /dev/null 2>&1
		f_myrm "$tmpfile"
		return 1
	fi

	f_msg NOTIFY "Waiting for $(( sleeptm - $sleep_before_first_snoop )) seconds before monitoring running processes (for exit)."
	sleep $(( sleeptm - $sleep_before_first_snoop ))
else
	# This is a fixed iteration run
	f_msg NOTIFY "This is a fixed-iteration run (see slob.conf->WORK_LOOP). "
	monitor_limit=0
fi

f_msg NOTIFY "Entering process monitoring loop."

while ( ps -p $pidstring > /dev/null 2>&1 )
do
	if [ "$monitor_limit" -ne 0 ]
	then
		if [ "$cnt" -gt "$monitor_limit" ]
		then
			f_msg FATAL "The following SQL*Plus processes have not exited after $monitor_limit seconds."
			ps -fp $pidstring
			f_myrm "$tmpfile"
			return 1
		fi
	fi

	(( cnt = $cnt + 1 ))
	(( x = $cnt % 10 ))

	if [ "$x" = 0 ]
	then
		tmp=`f_count_pids "$tmpfile"`		
		f_msg NOTIFY "There are $tmp sqlplus processes remaining."
	fi	

	sleep 1
done

f_myrm "$tmpfile"

return 0
}

function f_strip_non_numeric() {
sed -e '/[a-zA-Z]/d' -e '/^$/d'  -e 's/[^0-9]//g'
return 0
}

function f_snap_database_stats() {
#global SLOB_TEMPDIR
local admin_conn="$1"
local stats_type="$2"
local snap=0
local ret=0
local tmp=""
local tmpfile="${SLOB_TEMPDIR}/${RANDOM}.${FUNCNAME}.out"

if ( ! f_create_temp_file "$tmpfile" )
then
        f_msg FATAL "${FUNCNAME}: Cannot create temporary file. Abort."
        return 1
fi

if [ "$stats_type" = "statspack" ]
then
	$admin_conn <<EOF > $tmpfile 2>&1
	WHENEVER SQLERROR EXIT 2;
	SET HEADING OFF
	SET FEEDBACK OFF
	SET PAGES 0

	VARIABLE SNAP NUMBER;
	BEGIN   
	:SNAP := STATSPACK.SNAP;   
	END;
	/
	PRINT SNAP
EOF
	ret=$?

	tmp="EXEC PERFSTAT.STATSPACK.SNAP failed. Error output follows:"
else
	# This is AWR
	$admin_conn <<EOF > $tmpfile 2>&1
	WHENEVER SQLERROR EXIT 2;
	SET HEADING OFF
	SET FEEDBACK OFF
	SET PAGES 0

	EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT
	SELECT MAX(SNAP_ID) FROM dba_hist_snapshot;
	EXIT;
EOF
	ret=$?
	tmp="EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT failed. Error output follows:"
fi

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "${FUNCNAME}: ${tmp}" >&2
	cat $tmpfile >&2
else
	cat $tmpfile | f_strip_non_numeric
	f_myrm "$tmpfile"
fi

return $ret
}

function f_generate_awr_report() {
local admin_conn="$1"
local begin_snap="$2"
local end_snap="$3"
local tmp=""

($admin_conn <<EOF
set echo off heading on underline on;
column inst_num  heading "Inst Num"  new_value inst_num  format 99999;
column inst_name heading "Instance"  new_value inst_name format a12;
column db_name   heading "DB Name"   new_value db_name   format a12;
column dbid      heading "DB Id"     new_value dbid      format 9999999999 just c;

column end_snap new_value end_snap;
column begin_snap new_value begin_snap;


select d.dbid            dbid
     , d.name            db_name
     , i.instance_number inst_num
     , i.instance_name   inst_name
  from v\$database d,
       v\$instance i;

define  begin_snap = '$begin_snap' ;
define  end_snap = '$end_snap' ;
define  num_days     = 1;
define  report_type  = 'html';
define  report_name  = 'awr.html';

@?/rdbms/admin/awrrpti
exit;
EOF
) &

($admin_conn <<EOF

set echo off heading on underline on;
column inst_num  heading "Inst Num"  new_value inst_num  format 99999;
column inst_name heading "Instance"  new_value inst_name format a12;
column db_name   heading "DB Name"   new_value db_name   format a12;
column dbid      heading "DB Id"     new_value dbid      format 9999999999 just c;

column end_snap new_value end_snap;
column begin_snap new_value begin_snap;


select d.dbid            dbid
     , d.name            db_name
     , i.instance_number inst_num
     , i.instance_name   inst_name
  from v\$database d,
       v\$instance i;

define  begin_snap = '$begin_snap' ;
define  end_snap = '$end_snap' ;

define  num_days     = 1;

define  report_type  = 'text';
define  report_name  = 'awr.txt';

@?/rdbms/admin/awrrpti

define  begin_snap = '$begin_snap' ;
define  end_snap = '$end_snap' ;
define  report_type  = 'text';
define  report_name = 'awr_rac.txt';

@?/rdbms/admin/awrgrpt.sql

define  begin_snap = '$begin_snap' ;
define  end_snap = '$end_snap' ;
define  report_type  = 'html';
define  report_name  = 'awr_rac.html';

@?/rdbms/admin/awrgrpt.sql

exit;

EOF
) &

wait

for tmp in awr.html awr_rac.html
do
	( f_compress_file $tmp ) &
done

wait

return 0
}

function f_generate_statspack_report() {
local admin_conn="$1"
local begin_snap="$2"
local end_snap="$3"
local tmp=""

($admin_conn <<EOF
WHENEVER SQLERROR EXIT 2;
set echo off heading on underline on;
column inst_num  heading "Inst Num"  new_value inst_num  format 99999;
column inst_name heading "Instance"  new_value inst_name format a12;
column db_name   heading "DB Name"   new_value db_name   format a12;
column dbid      heading "DB Id"     new_value dbid      format 9999999999 just c;

select d.dbid            dbid
     , d.name            db_name
     , i.instance_number inst_num
     , i.instance_name   inst_name
  from v\$database d,
       v\$instance i;

define  begin_snap = '$begin_snap' ;
define  end_snap = '$end_snap' ;
define  report_name  = 'statspack.txt';

@?/rdbms/admin/sprepins.sql

exit;

EOF
) &

wait

return 0
}

function f_compress_file() {
local f="$1"

if [ -f "$f" ]
then
	f_msg NOTIFY "Compressing file: \"$f\"."

	if ( ! gzip -9 $f > /dev/null 2>&1 )
	then
		f_msg WARNING "${FUNCNAME}: The gzip command failed. Cannot compression file: ${f}."

		return 1
	fi
else
	f_msg NOTIFY "Cannot compress file \"$f\"."
	f_msg NOTIFY "No such file."

	return 1
fi

return 0
}

function f_print_usage() {

echo "
${0} supports the following command usage:

1. Single Option Invocation.
        $ sh ${0} <number-of-SLOB-schemas-to-test>

2. Multiple Option Invocation 
   2.1 This invocation style requires *exactly* four options.
        $ sh ${0} -s <number-of-slob-schemas-to-test> -t <SLOB-threads-per-schema>

NOTE: With Single Option Invocation slob.conf->THREADS_PER_SCHEMA is used. If you
      want more than a single SLOB thread per schema set THREADS_PER_SCHEMA in slob.conf.
      The default setting for slob.conf->THREADS_PER_SCHEMA is 1.
      
      With Multiple Option Invocation slob.conf->THREADS_PER_SCHEMA is overridden.
      The number of SLOB threads per schema is taken from the argument passed 
      in with the -t option.

EXAMPLES:

      Example 1. 256 SLOB schemas each with slob.conf->THREADS_PER_SCHEMA number 
      of SLOB threads per schema:
        $ sh ${0} 256

      Example 2. 16 SLOB schemas each with 32 SLOB threads:
        $ sh ${0} -s 16 -t 32

NOTE: Example 2 produces 512 (16*32) Oracle Database sessions.

ADDITIONAL INFORMATION: The SLOB documentation at kevinclosson.net/slob or SLOB/doc 

"

return 0
}

function f_check_cmdline() {
#global SCHEMAS
local args="$*"
local tmp=""
local i=0

# The option/args must be either:
#
#     a) A single option that is an integer representing the number of schemas to test
# 	or
#     b) Four tokens: A -s option with integer arg **and** -t option with an integer arg
#
# This routine either echoes a value for SCHEMAS and returns or prepares the cmdline for
# getopts processing of multiple option invocation.

[[ $# -ne 1 && $# -ne 4 ]]  && return 1 # Force 1 or 4

if [[ "$#" -eq 1 ]] # Quickly handle single option invocation
then

	if ( ! f_is_int "$1" ) 
	then
		f_msg FATAL "Single Option Invocation requires one option: A non-zero integer."
		return 1
	fi

	if [[ "$1" -lt 1 ]]
	then
		f_msg FATAL "Single Option Invocation requires one option: A non-zero integer."
		return 1
	fi
	
	echo "$1"

	return 0
fi

# Deal with multiple option invocation.
# There are the requisite number of options greater than 1 and 
# now the first and third arg must be suitable for getopts processing

for tmp in $1 $3
do
	if ( ! echo "$tmp" | grep -q '\-' > /dev/null 2>&1 )
	then
		f_msg FATAL "Invalid Multiple Option Invocation option/argument pairs."
		return 1	
	fi		
done

return 0
}

#Main Program SLOB 2.5.3.0

export OS_TEMP=${OS_TEMP:=/tmp}
export SLOB_TEMPDIR=${SLOB_TEMPDIR:=/tmp}
export WORKDIR=$(pwd)
export FILE_OPERATIONS_AUDIT_TRAIL_FILE="${WORKDIR}/.file_operations_audit_trail.out"
export MISC_PIDS=""
SCHEMAS=""
CMDLINE_THREADS_PER_SCHEMA=""
opt=""
tmp=""
begin_snap=0
end_snap=0
ret=0

########################### Setup logging (debug), validate executables, create audit trail file

if ( ! f_create_temp_file "$FILE_OPERATIONS_AUDIT_TRAIL_FILE" )
then
        f_msg FATAL "${0}:${LINENO}: Cannot create SLOB file operations audit trail file (${FILE_OPERATIONS_AUDIT_TRAIL_FILE}). Abort."
	f_myexit 1
else
	f_msg NOTIFY "For security purposes all file and directory creation and deletions"	
	f_msg NOTIFY "performed by ${0} are logged in: ${FILE_OPERATIONS_AUDIT_TRAIL_FILE}."	
fi

SLOB_TEMPDIR=$( f_create_tempdir "$SLOB_TEMPDIR" )
ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "Cannot create SLOB temporary files directory. Abort."
	f_myexit 1
else
	f_msg NOTIFY "SLOB TEMPDIR is ${SLOB_TEMPDIR}. SLOB will delete this directory at the end of this execution."
fi

if [ "$SLOB_DEBUG" = "FALSE" ]
then
	export debug_outfile="/dev/null"
else
	export debug_outfile="${WORKDIR}/slob_debug.out"

	if ( ! cat /dev/null > $debug_outfile )
	then
		echo "Cannot create debug output file ($debug_outfile)."
		echo "Abort."
		f_myexit 1
	fi
fi

if ( ! type sqlplus  >> $debug_outfile 2>&1 )
then
	f_msg FATAL "sqlplus is not executable in ${PATH}."
	f_msg FATAL "SLOB abnormal end."
	f_myexit 1	
fi

if [ ! -x ./mywait ]
then
	f_msg FATAL " "
	f_msg FATAL "./mywait executable not found or wrong permissions."
	f_msg FATAL "Please change directories to ./wait_kit and execute make(1)."
	f_msg NOTIFY "Example: "
	f_msg NOTIFY " $ cd ./wait_kit "	
	f_msg NOTIFY " $ make "	
	f_msg FATAL "SLOB abnormal end."
	f_myexit 1
fi

##### Check command line #########################################################################

tmp=$(f_check_cmdline $*)  # either set SCHEMAS or validate the multiple option invocation cmdline
ret=$?

if [ "$ret" -ne 0 ]
then
	echo "$tmp"
	f_msg FATAL "Invalid command line. Abort."
	f_print_usage
	f_myexit 1
else
	SCHEMAS="$tmp"
fi

while getopts ":s:t:" opt 
do
	case "$opt" in
		s)
			SCHEMAS="$OPTARG"
			if ( ! f_is_int "$SCHEMAS" || [[ "$SCHEMAS" -lt 1 ]] )
			then
				f_msg FATAL "The -s option requires a non-zero integer argument."
				f_print_usage 
				f_myexit 1
			fi
		;;
		t)
			tmp="$OPTARG"
			if ( ! f_is_int "$tmp" || [[ "$tmp" -lt 1 ]] )
			then
				f_msg FATAL "The -t option requires a non-zero integer argument."
				f_print_usage 
				f_myexit 1
			else

				export CMDLINE_THREADS_PER_SCHEMA="$tmp"
			fi
		;;
		*) 
			f_print_usage
			f_myexit 1
		;;	
	esac
done


##### Source slob.conf  ##########################################################################

f_msg NOTIFY "Sourcing in slob.conf"
source ./slob.conf

# BLOCK_SZ Can be set in the environment or slob.conf. Not documented.
# SLOB supports all Oracle block sizes

BLOCK_SZ=${BLOCK_SZ:=8192}
MIN_SCALE=10000

# Just in case user deleted lines in slob.conf:

UPDATE_PCT=${UPDATE_PCT:=25}
RUN_TIME=${RUN_TIME:=300}
WORK_LOOP=${WORK_LOOP:=0}
SCALE=${SCALE:=10000}
WORK_UNIT=${WORK_UNIT:=256}
REDO_STRESS=${REDO_STRESS:=LITE}
HOT_SCHEMA_FREQUENCY=${HOT_SCHEMA_FREQUENCY:=0}
THREADS_PER_SCHEMA=${THREADS_PER_SCHEMA:=1}

DATABASE_STATISTICS_TYPE=${DATABASE_STATISTICS_TYPE:=statspack}
SCAN_PCT=${SCAN_PCT:=0}

DO_HOTSPOT=${DO_HOTSPOT:=FALSE}
HOTSPOT_MB=${HOTSPOT_MB:=10}
HOTSPOT_OFFSET_MB=${HOTSPOT_OFFSET_MB:=0}
HOTSPOT_FREQUENCY=${HOTSPOT_FREQUENCY:=0}

THINK_TM_FREQUENCY=${THINK_TM_FREQUENCY:=0}
THINK_TM_MIN=${THINK_TM_MIN:=.1}
THINK_TM_MAX=${THINK_TM_MAX:=.5}

ADMIN_SQLNET_SERVICE=${ADMIN_SQLNET_SERVICE:=''}
SQLNET_SERVICE_BASE=${SQLNET_SERVICE_BASE:=''}
SQLNET_SERVICE_MAX=${SQLNET_SERVICE_MAX:=''}
SYSDBA_PASSWD=${SYSDBA_PASSWD:='manager'}
DBA_PRIV_USER=${DBA_PRIV_USER:='system'}

EXTERNAL_SCRIPT=${EXTERNAL_SCRIPT:=''}

export OBFUSCATE_COLUMNS=${OBFUSCATE_COLUMNS:=FALSE}

# Handle command line overrides of slob.conf settings
if  [[ -n "$CMDLINE_THREADS_PER_SCHEMA" ]] 
then
	export THREADS_PER_SCHEMA=$CMDLINE_THREADS_PER_SCHEMA
fi

sqlplus_pids=""
before=""
tm=""
cmd=""
slobargs=""
connect_string=""
tmp=""
user_scale_value=""
do_rotor="FALSE"
sleep_secs=0
ret=0
nt=0
x=0
cnt=1
instance=1

export non_admin_connect_string=""
export admin_connect_string="${DBA_PRIV_USER}/${SYSDBA_PASSWD}"

#### Initial Sanity checks on slob.conf:
if [ ! -z "$EXTERNAL_SCRIPT" ]
then

	if [ ! -x "$EXTERNAL_SCRIPT" ]
	then
		f_msg FATAL "The user-specified external script ($EXTERNAL_SCRIPT) is not executable."
		f_msg FATAL "Abort."
		f_myexit 1
	fi
fi


##### Initial slob.conf sanity check##############################################################

f_msg NOTIFY "Performing initial slob.conf sanity check..."
f_msg NOTIFY ""

[[ "$RUN_TIME"  -lt 30 ]]   && f_msg FATAL "Minimum supported RUN_TIME 30 seconds." && f_myexit 1
[[ "$WORK_UNIT" -lt 3 ]]    && f_msg FATAL "Minimum supported WORK_UNIT is 3."      && f_myexit 1
[[ "$WORK_UNIT" -gt 1024 ]] && f_msg FATAL "Maximum supported WORK_UNIT is 1024."   && f_myexit 1

if ( ! f_validate_database_statistics_type "$DATABASE_STATISTICS_TYPE" )
then
	f_myexit 1
fi

if [ ! -z "$SQLNET_SERVICE_MAX" ]
then
	if (! f_is_int "$SQLNET_SERVICE_MAX")
	then
		f_msg FATAL ""
		f_msg FATAL "SQLNET_SERVICE_MAX must be set to either null or an integer.\""
		f_myexit 1
	fi

	[[ "$SQLNET_SERVICE_MAX" -eq 0 ]] && f_msg FATAL "When set, SQLNET_SERVICE_MAX must be set to a non-zero integer.\"" && f_myexit 1
fi

if [[ -z "$SQLNET_SERVICE_BASE" && -n "$SQLNET_SERVICE_MAX" ]] 
then
	f_msg FATAL ""
	f_msg FATAL "SQLNET_SERVICE_BASE is null but SQLNET_SERVICE_MAX is set to \"$SQLNET_SERVICE_MAX\". Abort." 
	f_msg FATAL ""
	f_msg FATAL "SQLNET_SERVICE_MAX can only be used to modify SQLNET_SERVICE_BASE"
	f_msg FATAL "such that SQLNET_SERVICE_BASE is appended with the numeral 1 through \$SQLNET_SERVICE_MAX"
	f_msg FATAL "For example, SQLNET_SERVICE_BASE=\"TEST\" and SQLNET_SERVICE_MAX=\"3\""
	f_msg FATAL "would cause connections to round-robin SQL*Net connections from TEST1 through TEST3"
	f_myexit 1
fi

if [[ -n "$ADMIN_SQLNET_SERVICE" && -z "$SQLNET_SERVICE_BASE" ]]
then
	f_msg FATAL "ADMIN_SQLNET_SERVICE is not null but SQLNET_SERVICE_BASE is null." 
	f_msg FATAL "This is an unsupported configuration as it directs admin connections"
	f_msg FATAL "through the $ADMIN_SQLNET_SERVICE but user connetions via"
	f_msg FATAL "the bequeath (non SQL*Net) connections."
	f_msg ""
	f_msg "If ADMIN_SQLNET_SERVICE is set then SQLNET_SERVICE_BASE needs to also be set"
	f_msg "to either the same SQL*Net service or a different SQL*Net service"
	f_myexit 1

fi

# Enforce maximum tested database sessions
if [[ "$(( SCHEMAS * THREADS_PER_SCHEMA ))" -gt 4096 ]]
then
	f_msg FATAL "Cannot attach ${THREADS_PER_SCHEMA} (slob.conf) sessions to $SCHEMAS schemas."
	f_msg FATAL "Maximum tested active database session count is 4096."
	f_msg FATAL "Abort."
	f_myexit 1
fi

# This section determines how admin connections will occur. The user may wish to have 
# Admin connections through one SQL*Net service but runtime users connect through another

if [ -n "$ADMIN_SQLNET_SERVICE" ]
then
	# The user specified DBA conenction to the instance via SQL*Net. Enforce setting SYSDBA_PASSWD.

	[[ -z "$SYSDBA_PASSWD" ]] && f_msg FATAL "ADMIN_SQLNET_SERVICE is set so SYSDBA_PASSWD must also be set." && f_myexit 1

	if [ ! -z "$DBA_PRIV_USER" ]
	then
		export admin_connect_string="${DBA_PRIV_USER}/${SYSDBA_PASSWD}@${ADMIN_SQLNET_SERVICE}"
	else
		export admin_connect_string="system/${SYSDBA_PASSWD}@${ADMIN_SQLNET_SERVICE}"
	fi
fi

# This section takes care of how the runtime users connect

if [ -n "$SQLNET_SERVICE_BASE" ]
then
	export non_admin_connect_string="@${SQLNET_SERVICE_BASE}"

	if [[ -n "$SQLNET_SERVICE_MAX" && "$SQLNET_SERVICE_MAX" -ge 1 ]]
	then

		do_rotor=TRUE	

		if [ "$SQLNET_SERVICE_MAX" -eq 1 ]
		then
			# User wants all SLOB sessions connected through ${SQLNET_SERVICE_BASE}${SQLNET_SERVICE_MAX}  (e.g., RAC1)
			f_msg NOTIFY "All SLOB sessions will connect to service name \"${SQLNET_SERVICE_BASE}${SQLNET_SERVICE_MAX}\" via SQL*Net."
		else
			# User wants round-robin from 1 through N (e.g., RAC1,RAC2,RAC3,RAC4)

			if [ "$SCHEMAS" -eq 1 ]
			then
				(( sqlnet_batch = $THREADS_PER_SCHEMA / $SQLNET_SERVICE_MAX ))
			else
				(( sqlnet_batch = ( $SCHEMAS * $THREADS_PER_SCHEMA) / $SQLNET_SERVICE_MAX ))

			fi

			f_msg NOTIFY "SLOB session(s) will connect round-robin from ${SQLNET_SERVICE_BASE}1 through ${SQLNET_SERVICE_BASE}${SQLNET_SERVICE_MAX} via SQL*Net."
			f_msg NOTIFY "Instances 1 through ${SQLNET_SERVICE_MAX} will each have $sqlnet_batch sessions connected."
		fi
	else
		# User wants all SLOB sessions connected through SQLNET_SERVICE_BASE (e.g., RAC)
		f_msg NOTIFY "All SLOB sessions will connect to ${SQLNET_SERVICE_BASE} via SQL*Net."
	fi
else
	# SQLNET_SERVICE_BASE is not set
	f_msg NOTIFY "SQLNET_SERVICE_BASE is not set. Users will connect via bequeth connections (not SQL*Net)."
fi

admin_conn="sqlplus -L $admin_connect_string"
admin_conn_silent="sqlplus -S -L $admin_connect_string"

echo "
        NOTE Connect strings: 
               admin_conn: >>>${admin_conn}<<<
               admin_conn_silent: >>>${admin_conn_silent}<<<
               non_admin_connect_string: >>>${non_admin_connect_string}<<<
     " >> $debug_outfile 2>&1

# Use f_fix_scale to convert any legal value to number of blocks
user_scale_value="$SCALE"
SCALE=$(f_fix_scale "$BLOCK_SZ" "$user_scale_value") 

ret=$?

if [ "$ret" -ne 0 ]
then
        f_msg FATAL "The value assigned to slob.conf->SCALE ($user_scale_value [$SCALE]) is an illegal value."
        f_msg FATAL "Illegal SCALE value. Mininum supported value is $MIN_SCALE blocks."
        f_msg FATAL "Abort."
        f_myexit 1
fi

# Check to make sure the schemas have enough data to cover the testing
f_msg NOTIFY "Connecting to the instance to validate slob.conf->SCALE setting."

if ( ! f_validate_scale "$SCALE" "$SCHEMAS" user1 "$non_admin_connect_string" )
then
	f_msg FATAL ""
	f_msg FATAL "User specified testing SCALE $SCALE per schema."
	f_msg FATAL "Insufficient data has been loaded to test at scale $SCALE (per schema)."
	f_msg FATAL ""
	f_myexit 1
fi

#Set up output strings

if [ -n "$CMDLINE_THREADS_PER_SCHEMA" ]
then
        disp1="THREADS_PER_SCHEMA: $THREADS_PER_SCHEMA (-t option)"
fi

echo " 
UPDATE_PCT: $UPDATE_PCT			
SCAN_PCT: $SCAN_PCT
RUN_TIME: $RUN_TIME
WORK_LOOP: $WORK_LOOP			
SCALE: $user_scale_value ($SCALE blocks)
WORK_UNIT: $WORK_UNIT			
REDO_STRESS: $REDO_STRESS
HOT_SCHEMA_FREQUENCY: $HOT_SCHEMA_FREQUENCY
HOTSPOT_MB: $HOTSPOT_MB
HOTSPOT_OFFSET_MB: $HOTSPOT_OFFSET_MB
HOTSPOT_FREQUENCY: $HOTSPOT_FREQUENCY
THINK_TM_FREQUENCY: $THINK_TM_FREQUENCY
THINK_TM_MIN: $THINK_TM_MIN
THINK_TM_MAX: $THINK_TM_MAX
DATABASE_STATISTICS_TYPE: $DATABASE_STATISTICS_TYPE
SYSDBA_PASSWD: \"$SYSDBA_PASSWD\"
DBA_PRIV_USER: \"$DBA_PRIV_USER\"
ADMIN_SQLNET_SERVICE: \"$ADMIN_SQLNET_SERVICE\"
SQLNET_SERVICE_BASE: \"$SQLNET_SERVICE_BASE\"
SQLNET_SERVICE_MAX: \"$SQLNET_SERVICE_MAX\"

EXTERNAL_SCRIPT: \"$EXTERNAL_SCRIPT\"
${disp1}

Note: `basename $0` will use the following connect strings as per slob.conf settings:
	Admin Connect String: \"$admin_connect_string\"
"

f_check_for_stragglers

f_clean_old_files "statspack.txt awr.txt awr_rac.txt awr.html awr.html.gz awr_rac.html.gz iostat.out vmstat.out mpstat.out db_stats.out sqlplus.out slob_debug.out"

for tmp in $UPDATE_PCT $SCAN_PCT $RUN_TIME $WORK_LOOP $WORK_UNIT $HOT_SCHEMA_FREQUENCY $HOTSPOT_MB $HOTSPOT_OFFSET_MB $HOTSPOT_FREQUENCY 
do
	if ( ! f_is_int "$tmp" )
	then
		f_msg FATAL "These slob.conf parameters must be assigned integer values:
		UPDATE_PCT SCAN_PCT RUN_TIME WORK_LOOP WORK_UNIT HOT_SCHEMA_FREQUENCY HOTSPOT_MB HOTSPOT_OFFSET_MB HOTSPOT_FREQUENCY "
		f_msg FATAL "\"$tmp\" is not an integer. Please check slob.conf."
		f_myexit 1
	fi
done


if ( ! f_check_pct_logic "$UPDATE_PCT" )
then
	f_msg FATAL "*************************************************************************"
	f_msg FATAL "Values between 51 and 99 for UPDATE_PCT render non-deterministic results."
	f_msg FATAL "The slob.conf value assigned to UPDATE_PCT is $UPDATE_PCT"
	f_msg FATAL ""
	f_msg FATAL "Please choose values in the following ranges: 0-50 or 100 for optimal"
	f_msg FATAL "test repeatability."
	f_msg FATAL "*************************************************************************"
	f_myexit 1
fi

if ( ! f_check_pct_logic "$SCAN_PCT" )
then
	f_msg FATAL "*************************************************************************"
	f_msg FATAL "Values between 51 and 99 for SCAN_PCT render non-deterministic results."
	f_msg FATAL "The slob.conf value assigned to SCAN_PCT is $SCAN_PCT"
	f_msg FATAL ""
	f_msg FATAL "Please choose values in the following ranges: 0-50 or 100 for optimal"
	f_msg FATAL "test repeatability."
	f_msg FATAL "*************************************************************************"
	f_myexit 1
fi

# Check Hotspot settings for sanity
if [ "$DO_HOTSPOT" = "TRUE" ]
then
	if ( ! f_check_hotspot_logic "$BLOCK_SZ" "$SCALE" "$HOTSPOT_MB" "$HOTSPOT_OFFSET_MB" )
	then
		f_msg FATAL "Abort."
		f_myexit 1
	fi
fi

f_msg NOTIFY "Testing admin connectivity to the instance to validate slob.conf settings."

if ( ! f_test_conn "$admin_connect_string" )
then
        f_msg FATAL "Cannot connect to the instance."
	f_msg FATAL "Connect string: \"${admin_connect_string}\"."
        f_msg FATAL "Please verify the instance and listener are running and the settings"
        f_msg FATAL "in slob.conf are correct for your connectivity model."
	f_msg FATAL ""
	f_msg FATAL "Also check DBA_PRIV_USER/SYSDBA_PASSWD settings."
	f_msg FATAL ""
	f_msg FATAL "If not connecting with SQL*Net please check \$ORACLE_SID."
	f_msg FATAL "Current value for \$ORACLE_SID is \"$ORACLE_SID\"."
	f_msg FATAL ""
	
	f_msg FATAL "SLOB abnormal end."

	f_myexit 1 
fi

# The following section tests if the schemas exist and can be accessed via SQL*Net as per
# the settings in slob.conf
#

f_msg NOTIFY "Next, testing ${SCHEMAS} user (non-admin) connections..."

if [ "$do_rotor" = "TRUE" ]
then

	if [[ "$(( SCHEMAS % SQLNET_SERVICE_MAX ))" != 0 ]]
	then
		f_msg WARNING "**********"
		f_msg WARNING "Schema count ($SCHEMAS) is not an even multiple of ${SQLNET_SERVICE_MAX}. Sessions per instance will not by symmetrical."
		f_msg WARNING "**********"
	fi

	for (( i = 1 ; i <= $SQLNET_SERVICE_MAX ; i++ ))
	do
		connect_string="${non_admin_connect_string}${i}"

		for U in 1 ${SCHEMAS} 
		do

			if ( ! f_test_conn "user${U}/user${U}${connect_string}" )
			then
				f_msg FATAL "Connect failure user${U}/user${U}${connect_string}."
				f_msg FATAL "Please ensure:"
				f_msg FATAL " a) user${U} exists in the database"
				f_msg FATAL " b) ${connect_string} is a valid SQL*Net service in tnsnames.ora."
				f_msg FATAL "SLOB abnormal end."
				f_myexit 1
			fi
		done
	done
else
	# Not going to rotor the connections $do_rotor != TRUE

	for U in 1 ${SCHEMAS} 
	do

		if ( !  f_test_conn "user${U}/user${U}${non_admin_connect_string}" )
		then

			f_msg FATAL "Connect failure user${U}/user${U}${non_admin_connect_string}."
			f_msg FATAL "Please ensure user${U} exists in the database."
			f_msg FATAL "SLOB abnormal end."
			f_myexit 1
		fi

		[[ "$SCHEMAS" -eq 1 ]] && break
	done
fi

f_msg NOTIFY "Performing redo log switch."
sqlplus $admin_connect_string @./misc/switchlog > /dev/null 2>&1

f_msg NOTIFY "Redo log switch complete. Setting up trigger mechanism."
./create_sem > /dev/null 2>&1

if [  -z "$NO_OS_PERF_DATA" ]
then
	f_msg NOTIFY "Running iostat, vmstat and mpstat on current host--in background."
	( iostat -t -xm 3 > iostat.out 2>&1 ) &
	MISC_PIDS="${MISC_PIDS} $!"
	( vmstat -t 3 > vmstat.out 2>&1 ) &
	MISC_PIDS="${MISC_PIDS} $!"
	( mpstat -P ALL 3  > mpstat.out 2>&1) &
	MISC_PIDS="${MISC_PIDS} $!"
fi


f_msg NOTIFY "Connecting ${THREADS_PER_SCHEMA} (THREADS_PER_SCHEMA) session(s) to ${SCHEMAS} schema(s) ..."

#
# Launch the sessions
#


arg1=""
arg2=$UPDATE_PCT
arg3=$WORK_LOOP
arg4=$RUN_TIME
arg5=$SCALE 
arg6=$WORK_UNIT 
arg7=$REDO_STRESS 
arg8=$HOT_SCHEMA_FREQUENCY 
arg9=$DO_HOTSPOT 
arg10=$HOTSPOT_MB 
arg11=$HOTSPOT_OFFSET_MB
arg12=$HOTSPOT_FREQUENCY 
arg13=$THINK_TM_FREQUENCY 
arg14=$THINK_TM_MIN 
arg15=$THINK_TM_MAX
arg16=$SCAN_PCT
arg17=$OBFUSCATE_COLUMNS

cnt=1 ; x=0 ; spawn_throttle=0 ; instance=1  

until [ "$cnt" -gt "$SCHEMAS" ]
do

	arg1=$cnt

	slobargs="$arg1 $arg2 $arg3 $arg4 $arg5 $arg6 $arg7 $arg8 $arg9 $arg10 $arg11 $arg12 $arg13 $arg14 $arg15 $arg16 $arg17"

	if [ "$do_rotor" = "TRUE" ]
	then
		cmd="sqlplus -s user${cnt}/user${cnt}${non_admin_connect_string}${instance}"
		(( instance = $instance + 1 ))
		[[ "$instance" -gt "$SQLNET_SERVICE_MAX" ]] && instance=1
	else
		cmd="sqlplus -s user${cnt}/user${cnt}${non_admin_connect_string}"
	fi

	for ((i=0 ; i < $THREADS_PER_SCHEMA ; i++))
	do

		if [[ "$SCHEMAS" -eq 1 && "$do_rotor" = "TRUE" ]]
		then
			cmd="sqlplus -s user${cnt}/user${cnt}${non_admin_connect_string}${instance}"
			(( instance = $instance + 1 ))
			[[ "$instance" -gt "$SQLNET_SERVICE_MAX" ]] && instance=1
		fi

		(( spawn_throttle = $spawn_throttle + 1 ))

		( $cmd @slob $slobargs >> $debug_outfile 2>&1 ) &
		sqlplus_pids="${sqlplus_pids} $!"
		(( x = $spawn_throttle % 17 ))
		[[ "$x" -eq 0 ]] && spawn_throttle=0 && sleep .5
	done

	(( cnt = $cnt + 1 ))
done

f_msg NOTIFY " "

if [[  "$(( cnt / 6 ))" -gt 5 ]]
then
	sleep_secs=5
else
	(( sleep_secs = $cnt / 6 ))
fi

if [ "$sleep_secs" -gt 1 ]
then
	f_msg NOTIFY "Pausing for $sleep_secs seconds before triggering the test."
	sleep $sleep_secs
fi

if ( ! f_execute_external_script "$EXTERNAL_SCRIPT" pre )
then
	f_msg FATAL "External script execution failure. Check permissions on ${EXTERNAL_SCRIPT}."
	f_myexit 1
fi

# Switch output to fd2 so $MISC_PIDS shell kill feedback falls in line


./trigger > /dev/null 2>&1
before=$SECONDS

f_msg NOTIFY "Test has been triggered. Processes are executing. Warm-up phase." >&2

sleep 30

f_msg NOTIFY "Executing ${DATABASE_STATISTICS_TYPE} \"before snap\" procedure. Command: \"$admin_conn_silent\"." >&2
begin_snap=`f_snap_database_stats "$admin_conn_silent" "$DATABASE_STATISTICS_TYPE"`

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "Failed to take database statistics snapshot."
	f_myexit 1
else
	f_msg NOTIFY "Before ${DATABASE_STATISTICS_TYPE} snap ID is ${begin_snap}"
fi

f_msg NOTIFY " "

if ( ! f_wait_pids "$(( SCHEMAS * THREADS_PER_SCHEMA ))" "$RUN_TIME" "$WORK_LOOP" "$sqlplus_pids" )
then
	f_msg FATAL "This is not a successful SLOB test. Some sqlplus processes aborted." >&2
	f_myexit 1
fi

(( tm =  $SECONDS - $before - 30 ))

f_msg NOTIFY "Run time ${tm} seconds." >&2
echo "Tm $tm" > tm.out

if ( ! f_execute_external_script "$EXTERNAL_SCRIPT" post )
then
	f_msg NOTIFY "External script execution (post) failure."
fi

f_msg NOTIFY "Executing ${DATABASE_STATISTICS_TYPE} \"after snap\" procedure. Command: \"$admin_conn_silent\"." >&2
end_snap=`f_snap_database_stats "$admin_conn_silent" "$DATABASE_STATISTICS_TYPE"`

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "Failed to take database statistics snapshot."
	f_myexit 1
else
	f_msg NOTIFY "After ${DATABASE_STATISTICS_TYPE} snap ID is ${end_snap}"
fi

if [ "$DATABASE_STATISTICS_TYPE" = "statspack" ]
then
	( f_generate_statspack_report "$admin_conn" "$begin_snap" "$end_snap" >> $debug_outfile ) &
else
	( f_generate_awr_report "$admin_conn" "$begin_snap" "$end_snap" >> $debug_outfile ) &
fi

f_msg NOTIFY "Terminating background data collectors." >&2

f_kill_misc_pids 

wait

mv ${OS_TEMP}/db_stats.out . > /dev/null 2>&1

f_msg NOTIFY ""
f_msg NOTIFY "SLOB test is complete."

if ( ! f_execute_external_script "$EXTERNAL_SCRIPT" end )
then
	f_msg NOTIFY "External script execution (end) failure."
fi

f_check_for_stragglers

f_myexit 0


