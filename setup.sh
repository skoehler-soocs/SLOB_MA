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

function f_create_file() {
local f="$1"

if ( ! cat /dev/null > $f )
then
	f_msg FATAL ""
	f_msg FATAL "Cannot create file $f "
	f_msg FATAL ""
	return 1	
fi

if [ ! -w "$f" ]
then
	f_msg FATAL ""
	f_msg FATAL "File $f is not a writable file"
	f_msg FATAL ""
	return 1
fi

return 0
}

function f_check_wait_kit() {
local f=""

for f in mywait trigger create_sem
do
	if [ ! -x "./$f" ]
	then
		f_msg NOTIFY "Please do not forget to compile the wait kit."
		f_msg NOTIFY "Please change directories to ./wait_kit and execute make(1)."
		f_msg NOTIFY "Example: "
		f_msg NOTIFY " $ cd ./wait_kit "
		f_msg NOTIFY " $ make "
		return 1
	fi
done
return 0
}

function f_abort_msg() {
local f=$1 
if ( sed -n '/^ERROR/{n;p;}' < $f | grep -v 'ORA-00942' > /dev/null 2>&1 )
then
	echo ; echo ; echo  
	f_msg FATAL "The following errors appear in ${LOG}:"
	echo 
	sed -n '/^ERROR/{n;p;}' < $f | grep -v 'ORA-00942'
	echo 
fi

return 0
}


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

if ( ! echo $s |  grep -q "^-\?[0-9]*$" )
then
	return 1
else
	return 0
fi

return 0
}

function f_fix_scale() {
local bsz="$1"
local scale="$2"
local min_blocks="$3"
local factor=""

# Check for permissible values first
factor=$( echo "$scale" | sed 's/[0-9 KMGT]//g'   )

if [ -n "$factor" ] 
then
	return 1
fi

# Work out scale:
factor=$( echo "$scale" | sed 's/[^KMGT]//g'   )

if [ -z "$factor" ]
then
        # This is a simple integer assigment case
        scale=$( echo "$scale" | sed 's/[^0-9]//g' )
else
        scale=$( echo "$scale" | sed 's/[^0-9]//g' )
        case "$factor" in
                "K") (( scale = ( 1024 * $scale  ) / $bsz ))  ;;
                "M") (( scale = ( 1024 * 1024 * $scale  ) / $bsz ))  ;;
                "G") (( scale = ( 1024 * 1024 * 1024 * $scale  ) / $bsz )) ;;
                "T") (( scale = ( 1024 * 1024 * 1024 * 1024 *  $scale  ) / $bsz )) ;;
                * ) return 1 ;;
        esac
fi

if ( ! f_is_int "$scale" )
then
	f_msg FATAL "${FUNCNAME}: Computed is: \"${scale}\". Please report this logic error."
	return 1
fi

if [ "$scale" -lt "$min_blocks" ]
then
	echo $scale
	return 1
else

	echo $scale
	return 0
fi

return 0
}

function f_flag_abort() {
#global LOG
local f="$1"

f_msg FATAL ""
f_msg FATAL "${FUNCNAME}: Triggering abort"
f_msg FATAL ""

if ( ! cat /dev/null >  $f >> $LOG 2>&1 )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: failed to trigger abort"
	f_msg FATAL ""
	return 1
fi

return 0
}

function f_check_abort_flag() {
local f="$1"

if [ -f "$f" ]
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: discovered abort flag"
	f_msg FATAL ""
	return 0
fi

return 1
}

function f_test_oracle_utilities() {
#global LOG
local exe=""

for exe in sqlplus tnsping
do 
	if ( ! type $exe >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Please validate your environment. SQL*Plus is not executable in current \$PATH"
		f_msg FATAL ""
		return 1
	fi
done

return 0
}

function f_test_conn() {
local constring="$*"
local ret=0

f_msg NOTIFY "Test connectivity with: \"sqlplus -L $constring\""

sqlplus -L "$constring" <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON
PROMPT Performing connectivity and database state check
SELECT COUNT(*) FROM dual;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL
	f_msg FATAL "${FUNCNAME}: Failed connectivity check"
	f_msg FATAL
fi

return $ret
}

function f_check_for_sessions() {
local constring="$1"
local num_sessions=""

num_sessions=`sqlplus -S -L $constring  <<EOF
set head off
SELECT COUNT(*) FROM V\\$SESSION WHERE USERNAME LIKE 'USER%';
EOF
`

num_sessions=$( echo "$num_sessions" | f_sqlplus_numeric_only_output )

[[ $num_sessions -ne 0 ]] && return 1

return $num_sessions
}

function f_check_mto() {
local constring="$1"
local cdb=""

cdb=`sqlplus -L $constring <<EOF
SET HEAD OFF
PROMPT Query: SELECT CDB from V\\$DATABASE 
SELECT CDB FROM V\\$DATABASE ;
PROMPT End of output from SELECT
EOF
`
if ( echo "$cdb" | grep -q "YES" > /dev/null 2>&1 )
then
	return 1
else
	if ( echo "$cdb" | grep -q "NO" > /dev/null 2>&1 )
	then
		return 0
	else
		f_msg FATAL "${FUNCNAME}: Logic error 1. Please report this failure:"
		echo "####################################################################################################"
		echo "Error text: >>>>${cdb}<<<<"
		echo "####################################################################################################"
	
		exit 1
	fi
fi
# Cannot get here unless logic bug
f_msg FATAL "${FUNCNAME}: Logic error 2. Please report this error."
exit 1
}

function f_test_listener() {
#global LOG
local svc="$1"

if ( ! tnsping $svc >> $LOG 2>&1 )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: tnsping failed to validate SQL*Net service ( $svc )"
	f_msg FATAL "Examine $LOG"
	return 1
fi

return 0
}


function f_test_tablespace() {
local constring="$1"
local tablespace="$2"
local ret=0

f_msg NOTIFY "Testing user-specified tablespace suitability"

sqlplus -L "$constring" <<EOF 2>&1
SET TERMOUT ON
SET ECHO ON
PROMPT
PROMPT The following is a test of the user-specified tablespace
PROMPT Performing the following tasks: 
PROMPT 1) Drop SIMPLE_SLOB_TEST if exists (if it doesn't exist ORA-00942 is expected)
PROMPT 2) Create table SIMPLE_SLOB_TEST in tablespace $tablespace (user-specified)
PROMPT 3) Drop freshly created SIMPLE_SLOB_TEST table
PROMPT
DROP TABLE SIMPLE_SLOB_TEST PURGE;
WHENEVER SQLERROR EXIT 2;
CREATE TABLE SIMPLE_SLOB_TEST(c number)  TABLESPACE $tablespace ;
DROP TABLE SIMPLE_SLOB_TEST PURGE;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL
	f_msg FATAL "${FUNCNAME}: Failed tablespace suitability test"
	f_msg FATAL
else
	f_msg NOTIFY "Finished testing user-specified tablespace suitability"

fi

return $ret
}

function f_slob_tabs_report() {
#global WORK_DIR
#global SCALE
local constring="$*"
local ret=0
local outfile="${WORK_DIR}/slob_data_load_summary.txt"

if ( ! f_create_file "$outfile" )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Cannot create ${outfile}"
	f_msg FATAL ""
	return 1
fi

sqlplus -L "$constring" <<EOF 2>&1
WHENEVER SQLERROR EXIT 2;
SET TERMOUT ON
SET ECHO ON
SPOOL $outfile 
REM Values from ALL_TABLES are estimates unless full table
REM statistics are gathered. Values in the NUM_ROWS column should be
REM quite close to $SCALE to indicate data loading success.
REM
REM The SLOB tables should have $SCALE rows loaded as per slob.conf->SCALE
REM To get a precise number of rows for each schema one can perform:
REM SELECT MAX(custid) FROM cf1;
REM
SET LINESIZ 80
SET PAGESIZE 50000
COLUMN OWNER FORMAT a10
COLUMN TABLE_NAME FORMAT a10
COLUMN NUM_ROWS FORMAT 999,999,999,999
COLUMN BLOCKS FORMAT 999,999,999,999


WHENEVER SQLERROR EXIT 2;
SELECT OWNER, TABLE_NAME, NUM_ROWS, BLOCKS 
FROM ALL_TABLES WHERE TABLE_NAME LIKE 'CF%'
ORDER BY OWNER, TABLE_NAME;
EOF

ret=$?
if [ "$ret" -ne 0 ]
then
	f_msg FATAL
	f_msg FATAL "${FUNCNAME}: Failed to report on ALL_TABLES"
	f_msg FATAL
fi

return $ret
}

function f_sqlplus_numeric_only_output() {
sed -e '/[A-Z]/d' -e '/---/d' -e '/^$/d' -e 's/[^0-9]//g'
}

function f_drop_users(){
#global WORK_DIR
#global MAX_SLOB_SCHEMAS
#gloabl LOG
local constring="$1"
local fname="${WORK_DIR}/drop_users.log"
local num_processed=0
local sql=""
local schemas=0
local x=0

if ( ! f_create_file "$fname" )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Cannot create file ($fname)"
	f_msg FATAL ""
	return 1
fi

sql="SELECT REPLACE (MAX(LPAD(USERNAME,10)),'USER') FROM DBA_USERS  WHERE USERNAME LIKE 'USER%';" 
schemas=$( echo "$sql"| sqlplus -s "$constring" 2>&1 | f_sqlplus_numeric_only_output )

for (( x=0 ; x < ( $schemas + 1 )  ; x++ ))
do
        echo "SET ECHO ON 
	      DROP USER user${x} CASCADE ;"
done | sqlplus -s "$constring" 2>&1 | tee -a $fname |  grep -i "dropped" | wc -l  | while read num_processed
do
	if ( ! f_is_int "$num_processed" )
	then
		echo "REM WARNING: ${FUNCNAME}: Logic error (\"${num_processed}\" is not an integer value). Please report this warning." >> $fname
	else
		if [ "$num_processed" -gt 0 ]
		then
			f_msg NOTIFY "Deleted $(( num_processed - 1 )) SLOB schema(s)."
		fi
	fi
done

return 0
}

function f_gather_stats() {
local user="$1"
local pass="$2"
local degree="$3"
local constring="$4"
local ret=0
local sql=""

sql="ALTER TABLE cf1 PARALLEL "

if ( ! f_run_ddl "$user" "$pass" "$constring" "$sql" )
then
        f_msg FATAL "${FUNCNAME}: SQL execution failed in $user schema: \"${sql}\" "
        return 1
else
        f_msg NOTIFY "${FUNCNAME}: $user $pass $constring \"$sql\""
fi

f_msg NOTIFY "Gathering stats on user ${user} schema"

sqlplus ${user}/${pass}${constring} <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON
SET TIMING ON

PROMPT Gathering stats on user ${user} schema

ALTER SESSION FORCE PARALLEL DDL;
ALTER SESSION FORCE PARALLEL QUERY;

EXEC DBMS_STATS.GATHER_TABLE_STATS('$user1','cf1', estimate_percent => 5);

EXIT;
EOF
ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL
	f_msg FATAL "${FUNCNAME}: Failed to gather stats on $user schema"
	f_msg FATAL
fi

sql="ALTER TABLE cf1 NOPARALLEL"

if ( ! f_run_ddl $user $pass "$constring" "$sql" )
then
       f_msg FATAL "${FUNCNAME}: SQL execution failed in $user schema: \"${sql}\" "
       return 1
else
        f_msg NOTIFY "${FUNCNAME}: $user $pass $constring \"$sql\""
fi

return $ret
}

function f_grant() {
#global WORK_DIR
local user="$1"
local pass="T_ba_CZfq_EU_k_dn3J_VtP5j_w_Xr"
local tablespace="$2"
local constring="$3" 
local ret=0
local fname="${WORK_DIR}/drop_users.sql"

if ( ! f_create_file "$fname"  )
then
        f_msg FATAL ""
        f_msg FATAL "${FUNCNAME}: Cannot create file: $fname "
        f_msg FATAL ""
        return 1
fi

sqlplus "$constring" <<EOF
WHENEVER SQLERROR EXIT 2;
SET TERMOUT ON
SET ECHO ON

WHENEVER SQLERROR EXIT 2;
GRANT CONNECT TO $user IDENTIFIED BY $pass;
GRANT DBA TO $user;
ALTER USER $user DEFAULT TABLESPACE $tablespace ;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL
	f_msg FATAL "${FUNCNAME}: Failed to create $user schema or grants failed"
	f_msg FATAL
else
	# Leave behind a cleanup script
	echo "DROP USER $user CASCADE;" >> $fname 2>&1
fi

return $ret
}

function f_gen_basetable_sql() {
#global WORK_DIR
local tablespace="$1"
local s="$2"
local e="$3"
local fname="${WORK_DIR}/$4"
local obfuscate="$5"

( [[ "$obfuscate" != "TRUE" ]] && [[ "$obfuscate" != "FALSE" ]] )  && ( f_msg FATAL "Column obfuscation directive is neither TRUE, not FALSE." && return 1 )

if ( ! f_create_file "$fname" )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Cannot create file: $fname "
	f_msg FATAL ""
	return 1
fi

echo "
SET TERMOUT ON
SET TIMING ON
SET ECHO ON
WHENEVER SQLERROR EXIT 2;

CREATE TABLE keys_${s}(key NUMBER) PCTFREE 0 TABLESPACE $tablespace ;

DECLARE
        filler VARCHAR2(128) := '$(printf 'X%.0s' {1..128})';
	key   NUMBER;
	x1    VARCHAR2(128) := filler;
	x2    VARCHAR2(128) := filler;
	x3    VARCHAR2(128) := filler;
	x4    VARCHAR2(128) := filler;
	x5    VARCHAR2(128) := filler;
	x6    VARCHAR2(128) := filler;
	x7    VARCHAR2(128) := filler;
	x8    VARCHAR2(128) := filler;
	x9    VARCHAR2(128) := filler;
	x10   VARCHAR2(128) := filler;
	x11   VARCHAR2(128) := filler;
	x12   VARCHAR2(128) := filler;
	x13   VARCHAR2(128) := filler;
	x14   VARCHAR2(128) := filler;
	x15   VARCHAR2(128) := filler;
	x16   VARCHAR2(128) := filler;
	x17   VARCHAR2(128) := filler;
	x18   VARCHAR2(128) := filler;
	x19   VARCHAR2(128) := filler;
	v_seed VARCHAR2(32) := TO_CHAR(SYSTIMESTAMP,'YYYYDDMMHH24MISSFFFF');

	CURSOR c IS SELECT key FROM keys_$s ORDER BY DBMS_RANDOM.VALUE();

BEGIN

	DBMS_RANDOM.seed (val => v_seed);

	FOR key IN ${s} .. ${e} LOOP
		INSERT /*+ APPEND */ INTO keys_$s  VALUES (key);
		IF ( MOD( key, 1023 ) = 0 ) THEN
			COMMIT;
		END IF;
        
	END LOOP;
	COMMIT;

	OPEN  c;
	LOOP
		FETCH c INTO key;
		EXIT WHEN c%NOTFOUND;

		IF ( $obfuscate = TRUE ) THEN
			x1  := dbms_random.string('X', 128 );
			x2  := dbms_random.string('X', 128 );
			x3  := dbms_random.string('X', 128 );
			x4  := dbms_random.string('X', 128 );
			x5  := dbms_random.string('X', 128 );
			x6  := dbms_random.string('X', 128 );
			x7  := dbms_random.string('X', 128 );
			x8  := dbms_random.string('X', 128 );
			x9  := dbms_random.string('X', 128 );
			x10 := dbms_random.string('X', 128 );
			x11 := dbms_random.string('X', 128 );
			x12 := dbms_random.string('X', 128 );
			x13 := dbms_random.string('X', 128 );
			x14 := dbms_random.string('X', 128 );
			x15 := dbms_random.string('X', 128 );
			x16 := dbms_random.string('X', 128 );
			x17 := dbms_random.string('X', 128 );
			x18 := dbms_random.string('X', 128 );
			x19 := dbms_random.string('X', 128 );
		END IF;



	INSERT /*+ APPEND */ INTO cf1 VALUES (key,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19 );
	IF ( MOD( key, 31 ) = 0 ) THEN
		COMMIT;
	END IF;

	END LOOP;
	COMMIT;
	CLOSE c;
END;
/

DROP TABLE keys_$s ;
EXIT;
" > ${fname}

if [ ! -r "$fname" ]
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: $fname is not a readable file"
	f_msg FATAL ""
	return 1
fi

return 0

}

function f_setup_base_scan_table(){
local user="$1"
local pass="$2"
local scan_tbl_blocks="$3"
local constring="$4"
local ret=0

f_msg NOTIFY "Loading $user scan table with ${scan_tbl_blocks} blocks"

sqlplus ${user}/${pass}${constring}  <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf1 WHERE ROWNUM = 1 ;
COMMIT;

ALTER TABLE cf2 MINIMIZE RECORDS_PER_BLOCK;
TRUNCATE TABLE cf2 ;
COMMIT;

PROMPT Loading ${user}.cf2
-- Really no need to sort an unindexed table like this but you can choose:
-- INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf1 WHERE ROWNUM <= ${scan_tbl_blocks} ORDER BY DBMS_RANDOM.VALUE();
INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf1 WHERE ROWNUM <= ${scan_tbl_blocks};
COMMIT;

EXIT;
EOF

ret=$?

return ${ret}
}

function f_create_normal_scan_table() {
local user="$1"
local pass="$2"
local constring="$3"
local ret=0

sqlplus ${user}/${pass}${constring}  <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf2 WHERE ROWNUM = 1 ;
COMMIT;

ALTER TABLE cf2 MINIMIZE RECORDS_PER_BLOCK;
TRUNCATE TABLE cf2 ;
COMMIT;

PROMPT Loading ${user}.cf2
-- Really no need to sort an unindexed table like this but you can choose:
-- INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf2 ORDER BY DBMS_RANDOM.VALUE();
INSERT /*+ APPEND */ INTO cf2 SELECT * FROM user1.cf2 ORDER BY DBMS_RANDOM.VALUE();
COMMIT;

EXIT;
EOF

ret=$?

return ${ret}
}

function f_concurrent_table_load() {
#global LOG
#global SCALE
#global WORK_DIR

local tablespace="$1"
local threads="$2"
local user="$3"
local pass="$4"
local constring="$5"
local obfuscate="$6"
local sqlfile=""
local flagfile="$WORK_DIR/.abort"
local x=0
local b=0
local e=0
local tmp=0
local setsize=0

if (  f_create_file "$flagfile" )
then
	rm -f $flagfile
else
	f_msg FATAL ""
        f_msg FATAL "${FUNCNAME}: Cannot create file: $fname "
	f_msg FATAL ""

        return 1
fi

(( setsize = $SCALE / $threads ))

for (( x=0 ; $x < $threads ; x++ ))
do
	(( b = ( $x * $setsize ) +  1  ))
	(( e = ( $x + 1 ) * $setsize ))

	# Deal with the remainder:
	if [ "$x" -eq $(( threads - 1 )) ]
	then
		e="$SCALE"
	fi

	sqlfile="ins_${x}.sql"
	if ( ! f_gen_basetable_sql "$tablespace" "$b" "$e" "$sqlfile" "$obfuscate"  >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Concurrent load table setup failure"
		f_msg FATAL ""

		return 1	
	fi
done

# Now load the table 

tmp="$SECONDS"
for (( x=0 ; $x < $threads ; x++ ))
do
	sqlfile="ins_${x}.sql"

	if [ ! -r "$sqlfile" ] 
	then
		f_msg FATAL "$sqlfile is not readable"
		return 1
	fi

	( sqlplus "${user}/${pass}${constring}"  @${sqlfile} ; [[ $? -ne 0 ]] && touch "$flagfile" ;  rm -f "$sqlfile" ) &
done
wait

if [ -f "$flagfile" ]
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Concurrent base table load failure"
	f_msg FATAL ""
	rm -f "$flagfile"

	return 1
else
	f_msg NOTIFY "User ${user} schema loaded in $(( SECONDS - tmp )) seconds"
fi

rm -f "$flagfile"

return 0
}

function f_create_index() {
#global UNIQUE_INDEX 
local user="$1"
local pass="$2"
local tablespace="$3"
local degree="$4"
local constring="$5"
local sql=""
local ret=0

sql="ALTER TABLE cf1 PARALLEL"

if ( ! f_run_ddl "$user" "$pass" "$constring" "$sql" )
then
	f_msg FATAL "${FUNCNAME}: SQL execution failed in $user schema: \"${sql}\" "
	return 1
fi

sqlplus ${user}/${pass}${constring} <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

PROMPT Creating index on ${user}.cf1 

REM ALTER SESSION FORCE PARALLEL DDL;

SET TIMING ON
CREATE ${UNIQUE_INDEX} INDEX I_CF1 ON cf1(custid) NOPARALLEL PCTFREE 0 TABLESPACE $tablespace;

ALTER INDEX i_cf1 SHRINK SPACE COMPACT;

EXIT;
EOF

ret=$?

sql="ALTER TABLE cf1 NOPARALLEL"

if ( ! f_run_ddl "$user" "$pass" "$constring" "$sql" )
then
       f_msg FATAL "${FUNCNAME}: SQL execution failed in $user schema: \"${sql}\" "
       return 1
fi

return ${ret}
}

function f_run_ddl(){
local user="$1"
local pass="$2"
local constring="$3"
local sql="$4"
local ret=0

sqlplus ${user}/${pass}${constring} <<EOF
WHENEVER SQLERROR EXIT 2;
SET ECHO ON
PROMPT $sql
$sql ;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL "${FUNCNAME}: Failed to execute \"$sql\". Connect string: \"$user/${pass}${constring}\""
	return $ret
fi

return ${ret}
}

function f_setup_base_table () {
#global LOG
local user="$1"
local pass="$2"
local tablespace="$3"
local threads="$4"
local constring="$5"
local obfuscate="$6"

local ret=0
local tmp=0

sqlplus ${user}/${pass}${constring} <<EOF
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

PROMPT Forcing block sparseness on ${user}.cf1 
INSERT INTO cf1 VALUES (0, 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X');
COMMIT;

ALTER TABLE cf1 MINIMIZE RECORDS_PER_BLOCK;
TRUNCATE TABLE cf1 ;
COMMIT;
EXIT;
EOF

ret=$?

if [ "$ret" -ne 0 ]
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Failed to create base table"
	f_msg FATAL ""
	return 1
fi

f_msg NOTIFY "Preparing to load ${user} schema"

tmp="$SECONDS"

if ( ! f_concurrent_table_load "$tablespace" "$threads" "$user" "$pass" "$constring" "$obfuscate" >> $LOG 2>&1 )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: User ${user} table created but concurrent load procedure has failed"
	f_msg FATAL ""
	return 1
fi

tmp="$SECONDS"

if ( ! f_create_index "$user" "$pass" "$tablespace" 8 "$constring")
then
	f_msg FATAL "${FUNCNAME}: Create index procedure failed for ${user} schema"
	return 1
else
	f_msg NOTIFY "User ${user} index creation time: $(( SECONDS - tmp )) seconds"
fi

return 0
}

function f_load_normal_table() {
local user="$1"
local pass="$2"
local constring="$3"
local ret=0

sqlplus ${user}/${pass}${constring}  <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

INSERT INTO cf1 SELECT * FROM user1.cf1 WHERE ROWNUM = 1 ;
COMMIT;

ALTER TABLE cf1 MINIMIZE RECORDS_PER_BLOCK;
TRUNCATE TABLE cf1 ;
COMMIT;

PROMPT Loading ${user}.cf1
INSERT /*+ APPEND */ INTO cf1 SELECT * FROM user1.cf1 ORDER BY DBMS_RANDOM.VALUE();
COMMIT;

EXIT;
EOF

ret="$?"

return ${ret}
}

function f_create_table() {
local user="$1"
local pass="$2"
local tablespace="$3"
local constring="$4"
local ret=0

sqlplus ${user}/${pass}${constring} <<EOF
SET TERMOUT ON
WHENEVER SQLERROR EXIT 2;
SET ECHO ON

REM Never set custid NOT NULL

PROMPT Creating table ${user}.cf1
CREATE TABLE cf1
(
custid NUMBER(15), c2 VARCHAR2(128), c3 VARCHAR2(128) ,
c4 VARCHAR2(128) , c5 VARCHAR2(128) , c6 VARCHAR2(128) ,
c7 VARCHAR2(128) , c8 VARCHAR2(128) , c9 VARCHAR2(128) ,
c10 VARCHAR2(128) , c11 VARCHAR2(128) , c12 VARCHAR2(128) ,
c13 VARCHAR2(128) , c14 VARCHAR2(128) , c15 VARCHAR2(128) ,
c16 VARCHAR2(128) , c17 VARCHAR2(128) , c18 VARCHAR2(128) ,
c19 VARCHAR2(128) , c20 VARCHAR2(128) ) 
PARALLEL CACHE PCTFREE 99 TABLESPACE $tablespace 
STORAGE (BUFFER_POOL KEEP INITIAL 1M NEXT 1M MAXEXTENTS UNLIMITED);

PROMPT Creating table ${user}.cf2
CREATE TABLE cf2
(
custid NUMBER(15), c2 VARCHAR2(128), c3 VARCHAR2(128) ,
c4 VARCHAR2(128) , c5 VARCHAR2(128) , c6 VARCHAR2(128) ,
c7 VARCHAR2(128) , c8 VARCHAR2(128) , c9 VARCHAR2(128) ,
c10 VARCHAR2(128) , c11 VARCHAR2(128) , c12 VARCHAR2(128) ,
c13 VARCHAR2(128) , c14 VARCHAR2(128) , c15 VARCHAR2(128) ,
c16 VARCHAR2(128) , c17 VARCHAR2(128) , c18 VARCHAR2(128) ,
c19 VARCHAR2(128) , c20 VARCHAR2(128) ) 
NOCACHE PCTFREE 99 TABLESPACE $tablespace 
STORAGE (BUFFER_POOL KEEP INITIAL 1M NEXT 1M MAXEXTENTS UNLIMITED);
EXIT;
EOF

ret="$?"

return ${ret}
}

function f_cr_slob_procedure() {
local constring="$*"
local ret=0

f_msg NOTIFY "${PROGNAME}: Executing \"sqlplus -L "$constring" @./misc/procedure\" "

if ( ! sqlplus -L "$constring" @./misc/procedure 2>&1 | grep "No errors" )
then
	f_msg FATAL "Failed to compile ./misc/procedure.sql "
	f_msg FATAL "Failed command: \"sqlplus -L "$constring" @./misc/procedure 2>&1 | grep \"No errors\" \""
	return 1
fi

return 0
}

function f_setup() {
#global LOG
local user="$1"
local pass="$2"
local tablespace="$3"
local threads="$4"
local constring="$5"
local obfuscate="$6" 

if ( ! f_create_table "$user" "$pass" "$tablespace" "$constring" >> $LOG 2>&1 )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Failed to create table for ${user}."
	f_msg FATAL "${FUNCNAME}: pass: $pass connect string: $constring"
	f_msg FATAL ""

	return 1
fi

if [ "$user" = "user1" ]
then
	if ( ! f_setup_base_table "$user" "$pass" "$tablespace" "$threads" "$constring" "$obfuscate" >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to load ${user} SLOB table"
		f_msg FATAL ""

		return 1
	fi

	if ( ! f_setup_base_scan_table "$user" "$pass" "$SCAN_TABLE_SZ" "$constring" >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to load ${user} SLOB unindexed Scan table"
		f_msg FATAL ""

		return 1
	fi
	
        if ( ! f_gather_stats "$user" "$pass" 2 "$constring" >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to gather CBO stats for user ${user}"
		f_msg FATAL ""

		return 1			
	fi
else
	if ( ! f_load_normal_table "$user" "$pass" "$constring" >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to load ${user} SLOB table"
		f_msg FATAL ""

		return 1			
	fi

	if ( ! f_create_normal_scan_table "$user" "$pass" "$constring" >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to load ${user} SLOB scan table"
		f_msg FATAL ""

		return 1			
	fi

	if ( ! f_create_index "$user" "$pass" "$tablespace" 2 "$constring"  >> $LOG 2>&1 )
	then
		f_msg FATAL ""
		f_msg FATAL "${FUNCNAME}: Failed to create index in user ${user} schema"
		f_msg FATAL ""

		return 1			
	fi

	#if ( ! f_gather_stats "$user" "$pass" 2 "$constring" >> $LOG 2>&1 )
	#then
	#	f_msg FATAL ""
	#	f_msg FATAL "${FUNCNAME}: Failed to gather CBO stats for user ${user}"
	#	f_msg FATAL ""
	#	return 1			
	#fi
fi

return 0
}

function f_create_log(){
local f="$1"

if ( ! f_create_file "$f" )
then
	f_msg FATAL ""
	f_msg FATAL "${FUNCNAME}: Cannot create log file (${f})."
	f_msg FATAL ""
	return 1
fi

return 0
}

function f_pre_run_cleanup() {
#global ABORT_FLAG_FILE
local f=""

for f in drop_users.sql slob_data_load_summary.txt $ABORT_FLAG_FILE
do
	rm -f $f
done
return 0
}

function DEPRECATE_f_get_string() {
local obfuscate=$1

if [ "$obfuscate" = "FALSE" ]
then
	printf 'X%.0s' {1..128}	
else
	cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 128  | head -n 1
fi

return 0
}

#---------- Main body
export VERSION="SLOB 2.5.3.0"
export WORK_DIR=$( pwd )
export LOG=${WORK_DIR}/cr_tab_and_load.out
export ABORT_FLAG_FILE=$WORK_DIR/.abort_slob_load
export MAX_SLOB_SCHEMAS=4096
export MIN_SCALE_BLOCKS=10000
export MIN_SCAN_TABLE_BLOCKS=4


tmp=""
user_scale_value=""
user_scan_tbl_sz=""

if [ $# -ne 2 ] 
then
	f_msg FATAL ""
	f_msg FATAL "Incorrect command line options"
	f_msg FATAL "Usage : ${0}: <tablespace name> <number of SLOB schemas to create and load>" 
	f_msg FATAL ""
	exit 1
else

	if ( ! f_is_int "$2" )
	then
		f_msg FATAL "Usage : ${0}: <tablespace name> <number of SLOB schemas to create and load>"
		f_msg FATAL "Option 2 must be an integer"
		exit 1
	fi

	export TABLESPACE="$1"
	export SCHEMAS="$2"

	if [[ "$SCHEMAS" -le 0 || "$SCHEMAS" -gt "$MAX_SLOB_SCHEMAS" ]] 
	then
		f_msg FATAL ""
		f_msg FATAL "Number of SLOB schemas must be integer and tested maximum is $MAX_SLOB_SCHEMAS"
		f_msg FATAL "Usage : ${0}: <tablespace name> <number of SLOB schemas to create and load>"
		f_msg FATAL ""
		exit 1
	fi
fi

if [ ! -r ./slob.conf ]
then
	f_msg FATAL "There is no readable slob.conf file in `pwd`"
	exit 1		
fi

f_msg NOTIFY "Begin ${VERSION} setup."

if ( ! f_create_log "$LOG" )
then
	f_msg FATAL ""
	f_msg FATAL "Cannot create log file (\"${LOG}\")"
	f_msg FATAL ""
	exit 1
fi

if ( ! f_test_oracle_utilities )
then
	f_msg FATAL ""
	f_msg FATAL "Abort. See ${LOG}"
	f_msg FATAL ""
	exit 1
fi

f_pre_run_cleanup 
source ./slob.conf

export BLOCK_SZ=${BLOCK_SZ:=8192}
export UNIQUE_INDEX=${UNIQUE_INDEX:=''}
export LOAD_PARALLEL_DEGREE=${LOAD_PARALLEL_DEGREE:=1}
export SCALE=${SCALE:=10000}
export SCAN_TABLE_SZ=${SCAN_TABLE_SZ:=1M}
export ADMIN_SQLNET_SERVICE=${ADMIN_SQLNET_SERVICE:=''}
export DBA_PRIV_USER=${DBA_PRIV_USER:='system'}
export SYSDBA_PASSWD=${SYSDBA_PASSWD:='manager'}
export OBFUSCATE_COLUMNS=${OBFUSCATE_COLUMNS:=FALSE}
export NON_ADMIN_CONNECT_STRING=" " # NOTE: This must either be a whitespace or a functioning value
export ADMIN_CONNECT_STRING=""

# Work out whether this is SQL*Net or Bequeath and assign ADMIN_CONNECT_STRING

if [ -n "$ADMIN_SQLNET_SERVICE" ]
then
	#  We are using SQL*Net in this execution. Insist user provides SYSDBA_PASSWD.
	if [ -z "$SYSDBA_PASSWD" ] 
	then
		f_msg FATAL "ADMIN_SQLNET_SERVICE is set but you must also set SYSDBA_PASSWD when using SQL*Net."
		exit 1
	fi

	f_msg NOTIFY "$0 will use SQL*Net connection to create and load via tnsnames.ora service: $ADMIN_SQLNET_SERVICE"

	# Determine whether to use the "system" account or one specified by DBA_PRIV_USER
	if [ -n "$DBA_PRIV_USER" ]
	then
		#This execution is using SQL*Net, but wants to use a custom DBA account	
		f_msg NOTIFY "$0 will connect as \"$DBA_PRIV_USER\" with password \"$SYSDBA_PASSWD\""
		export ADMIN_CONNECT_STRING="${DBA_PRIV_USER}/${SYSDBA_PASSWD}@${ADMIN_SQLNET_SERVICE}"
	else

		#This execution is using SQL*Net, but user wants to use the system DBA account	
		export ADMIN_CONNECT_STRING="system/${SYSDBA_PASSWD}@${ADMIN_SQLNET_SERVICE}"
	fi

	export NON_ADMIN_CONNECT_STRING="@${ADMIN_SQLNET_SERVICE}"
else

	# This is not SQL*Net so process accordingly

	if [ -z "$DBA_PRIV_USER" ]
	then
		# Not SQL*Net and DBA_PRIV_USER is not set so this is a simple bequeath connect as the system user
		export ADMIN_CONNECT_STRING="${DBA_PRIV_USER}/${SYSDBA_PASSWD}"
	else
		# Not SQL*Net and DBA_PRIV_USER is set. Insist on SYSDBA_PASSWD.
		[[ -z "$SYSDBA_PASSWD" ]] && f_msg FATAL "If DBA_PRIV_USER is set then SYSDBA_PASSWD must be set"
		export ADMIN_CONNECT_STRING="$DBA_PRIV_USER/$SYSDBA_PASSWD"
	fi

fi

f_msg NOTIFY "ADMIN_CONNECT_STRING: \"$ADMIN_CONNECT_STRING\""

# Use f_fix_scale to convert any legal value to number of blocks for SCALE
user_scale_value="$SCALE"
SCALE=$(f_fix_scale "$BLOCK_SZ" "$user_scale_value" "$MIN_SCALE_BLOCKS" )  
ret=$?

if [ "$ret" -ne 0 ]
then
        f_msg FATAL "The value assigned to slob.conf->SCALE ($user_scale_value [$SCALE blocks]) is an illegal value. "
	f_msg FATAL "Illegal SCALE value. Mininum value is $MIN_SCALE_BLOCKS blocks"
        f_msg FATAL "Abort"
        exit 1
fi

# Use f_fix_scale to convert any legal value to number of blocks for SCAN_TABLE_SZ
user_scan_tbl_sz="$SCAN_TABLE_SZ"
SCAN_TABLE_SZ=$(f_fix_scale "$BLOCK_SZ" "$user_scan_tbl_sz" "$MIN_SCAN_TABLE_BLOCKS") ; ret=$?

if [ "$ret" -ne 0 ]
then
        f_msg FATAL "The value assigned to slob.conf->SCAN_TABLE_SZ ($user_scan_tbl_sz [$SCAN_TABLE_SZ blocks]) is an illegal value. "
	f_msg FATAL "Illegal SCAN_TABLE_SZ value. Mininum value is $MIN_SCAN_TABLE_BLOCKS blocks"
        f_msg FATAL "Abort"
        exit 1
fi


# Prepare the display strings

tmp1=""
[[ ! -z "$DBA_PRIV_USER" ]] && tmp1="SYSDBA_PASSWD: \"$SYSDBA_PASSWD\"
DBA_PRIV_USER: \"$DBA_PRIV_USER\""

f_msg NOTIFY "Load parameters from slob.conf: "
echo " 
SCALE: $user_scale_value ($SCALE blocks)
SCAN_TABLE_SZ: $user_scan_tbl_sz ($SCAN_TABLE_SZ blocks)
LOAD_PARALLEL_DEGREE: $LOAD_PARALLEL_DEGREE
ADMIN_SQLNET_SERVICE: \"$ADMIN_SQLNET_SERVICE\"
$tmp1

Note: `basename $0` will use the following connect strings as per slob.conf:
	Admin Connect String: \"$ADMIN_CONNECT_STRING\"
	Non-Admin Connect String: \"$NON_ADMIN_CONNECT_STRING\"
"

if [ -n "$ADMIN_SQLNET_SERVICE" ]
then

	f_msg NOTIFY "Testing listener status via tnsping to slob.conf->ADMIN_SQLNET_SERVICE (\"$ADMIN_SQLNET_SERVICE\")"

	if ( ! f_test_listener "$ADMIN_SQLNET_SERVICE" >> $LOG 2>&1 )
	then
		f_msg FATAL "slob.conf->ADMIN_SQLNET_SERVICE is set but tnsping cannot validate the service ($ADMIN_SQLNET_SERVICE)"
		f_msg FATAL "Please see ${LOG} for errors"
		exit 1
	fi
fi

f_msg NOTIFY "Testing Admin connect using \"sqlplus -L $ADMIN_CONNECT_STRING\""

if ( ! f_test_conn "$ADMIN_CONNECT_STRING" >> $LOG 2>&1  )
then
	f_msg FATAL "Cannot connect to the instance"
	f_msg FATAL "Check $LOG log file for more information"
	f_msg FATAL "Please verify the instance is running and the settings"
	f_msg FATAL "in slob.conf are correct for your connectivity model"
	f_msg FATAL ""
	f_msg FATAL "Also check DBA_PRIV_USER/SYSDBA_PASSWD settions."
	f_msg FATAL ""
	f_msg FATAL "If not connecting via SQL*Net please check \$ORACLE_SID"
	f_msg FATAL ""

	exit 1
fi

if ( ! f_check_mto "$ADMIN_CONNECT_STRING" 2>&1 >> $LOG)
then
	f_msg WARNING ""
	f_msg WARNING ""
	f_msg WARNING ""
	f_msg WARNING "This version of SLOB is not tested with Oracle Multitenant Option"
	f_msg WARNING ""
	f_msg WARNING ""
	f_msg WARNING ""

	#exit 1
	
fi


if ( ! f_check_for_sessions "$ADMIN_CONNECT_STRING" 2>&1 >> $LOG)
then
	f_msg FATAL ""
	f_msg FATAL "Please run the following query:
                                SELECT COUNT(*) FROM V\$SESSION WHERE USERNAME LIKE 'USER%';"
	f_msg FATAL "There are existing connections to the database."
	f_msg FATAL "Cannot drop schemas while sessions are connected."
	f_msg FATAL "Abort."

	exit 1
fi

USER=""
PASS=""

cnt=1
groupcnt=0
x=0
num_batches=0

if ( ! f_test_tablespace "$ADMIN_CONNECT_STRING" "$TABLESPACE" >> $LOG 2>&1 )
then
	f_msg FATAL "Cannot create tables in user-specified tablespace (\"$TABLESPACE\")"
	f_msg FATAL "See ${LOG}"
	exit 1
fi

f_msg NOTIFY "Dropping prior SLOB schemas. This may take a while if there is a large number of old schemas."
if ( ! f_drop_users "$ADMIN_CONNECT_STRING" )
then
	f_msg FATAL "Processing the DROP USER CACADE statements to remove any prior SLOB schemas failed."
	f_msg FATAL
	f_msg FATAL "Please check ${LOG}."
	f_msg FATAL ""

	exit 1
else
	f_msg NOTIFY "Previous SLOB schemas have been removed"
fi

if [ "$OBFUSCATE_COLUMNS" = "TRUE" ]
then
	f_msg NOTIFY "Loading obfuscated column data. Expect lower storage-level data compression."
fi


f_msg NOTIFY "Preparing to load $SCHEMAS schema(s) into tablespace: $TABLESPACE"

if [ "$SCHEMAS" -gt 1 ]
then
	# this is not single schema but how many batches?
	(( num_batches = ( $SCHEMAS - 1 ) / $LOAD_PARALLEL_DEGREE ))
		
fi

while [ "$cnt" -le "$SCHEMAS" ]
do
	if ( f_check_abort_flag "$ABORT_FLAG_FILE" )
	then
		f_msg FATAL "Aborting SLOB setup. See ${LOG}"
		f_abort_msg ${LOG}
		exit 1
	fi

	USER=user$cnt
	#PASS=user$cnt
        PASS="T_ba_CZfq_EU_k_dn3J_VtP5j_w_Xr"

	if [ "$cnt" -eq 1 ]
	then
		if ( ! f_grant "$USER" "$TABLESPACE" "$ADMIN_CONNECT_STRING" >> $LOG  2>&1 )
		then
			f_msg FATAL "Cannot create ${USER} schema. See ${LOG}"
			exit 1
		fi

		f_msg NOTIFY "Loading $USER schema"
		before_load_ts=$SECONDS

		if ( ! f_setup "$USER" "$PASS" "$TABLESPACE" "$LOAD_PARALLEL_DEGREE" "$NON_ADMIN_CONNECT_STRING" "$OBFUSCATE_COLUMNS" >> $LOG 2>&1 )
		then
			f_msg FATAL "Load procedure failed for $USER schema. See ${LOG}"
			exit 1
		fi

		before_concurrent_load="$SECONDS"

		f_msg NOTIFY "Finished loading and indexing user1 schema in $(( before_concurrent_load - before_load_ts )) seconds"

		if [  "$SCHEMAS" -gt 1 ]
		then
			f_msg NOTIFY "Commencing multiple, concurrent schema creation and loading"
		fi
	else

		if ( ! f_grant "$USER" "$TABLESPACE" "$ADMIN_CONNECT_STRING" >> $LOG  2>&1 )
		then
			f_msg FATAL "Cannot create ${USER} schema. See ${LOG}"
			exit 1
		fi

		( f_setup "$USER" "$PASS" "$TABLESPACE" "$LOAD_PARALLEL_DEGREE" "$NON_ADMIN_CONNECT_STRING" "$OBFUSCATE_COLUMNS" >> $LOG 2>&1 || f_flag_abort "$ABORT_FLAG_FILE" ) &

		if [ "$x" -eq $(( LOAD_PARALLEL_DEGREE - 1 ))  ] 
		then
			before_load_ts=$SECONDS
			(( groupcnt = $groupcnt + 1 ))
			f_msg NOTIFY "Waiting for background batch ${groupcnt}. Loading up to user${cnt}"  
			wait 

			f_check_abort_flag "$ABORT_FLAG_FILE" && f_abort_msg ${LOG} && f_msg FATAL "Aborting SLOB setup. See ${LOG}" && exit 1

			f_msg NOTIFY "Finished background batch ${groupcnt}. Loading and index creation complete : $(( SECONDS - before_load_ts )) seconds"  
			x=0
		else
			before_load_ts=$SECONDS
			(( x = $x + 1 ))
		fi
	fi
	(( cnt = $cnt + 1 ))
done

f_check_abort_flag "$ABORT_FLAG_FILE" && f_abort_msg ${LOG} && f_msg FATAL "Aborting SLOB setup. See ${LOG}" && exit 1

if [ "$SCHEMAS" -gt 1 ]
then
	if [[ $(( (SCHEMAS - 1)  % $LOAD_PARALLEL_DEGREE )) -ne 0  ]]
	then
		f_msg NOTIFY "Waiting for background batch $(( groupcnt + 1 )). Loading up to user${SCHEMAS}"
	fi

	f_check_abort_flag "$ABORT_FLAG_FILE" && f_abort_msg ${LOG} && f_msg FATAL "Aborting SLOB setup. See ${LOG}" && exit 1

	wait

	f_check_abort_flag "$ABORT_FLAG_FILE" && f_abort_msg ${LOG} && f_msg FATAL "Aborting SLOB setup. See ${LOG}" && exit 1

	(( concurrent_load_tm = $SECONDS - $before_concurrent_load ))
	if [[ "$num_batches" -gt 0  &&  $(( (SCHEMAS - 1)  % $LOAD_PARALLEL_DEGREE )) -ne 0 ]]
	then
		f_msg NOTIFY "Finished background batch $(( groupcnt + 1 )). Loading and index creation complete : $(( SECONDS - before_load_ts )) seconds"  
	fi

	f_msg NOTIFY "Completed concurrent data loading phase: ${concurrent_load_tm} seconds"
fi

# Create the user0 schema for spare and compatibility with older SLOB
if ( ! f_grant user0 "$TABLESPACE" "$ADMIN_CONNECT_STRING" >> $LOG  2>&1 )
then
	f_msg FATAL "Cannot create ${USER} schema. See ${LOG}"
	exit 1
fi

f_msg NOTIFY "Creating SLOB UPDATE procedure"

if ( ! f_cr_slob_procedure "$ADMIN_CONNECT_STRING" >> $LOG 2>&1 )
then
	f_msg FATAL "Failed to create SLOB PL/SQL procedure. Please examine $LOG for errors."
	exit 1
else
	f_msg NOTIFY "SLOB UPDATE procedure (./misc/procedure.sql) created."
fi

wait

if ( f_slob_tabs_report "$ADMIN_CONNECT_STRING" >> $LOG 2>&1 )
then
	f_msg NOTIFY "Row and block counts for SLOB table(s) reported in ./slob_data_load_summary.txt"
	f_msg NOTIFY "Please examine ./slob_data_load_summary.txt for any possbile errors" 
else
	f_msg FATAL "Failed to generate SLOB table row and block count report"
	f_msg FATAL "See ${LOG}"
	exit 1
fi

f_msg NOTIFY ""
f_msg NOTIFY "NOTE: No errors detected but if ./slob_data_load_summary.txt shows errors then"
f_msg NOTIFY "examine ${LOG}"
echo ""

f_msg NOTIFY "SLOB setup complete. Total setup time:  (${SECONDS} seconds)"

f_check_wait_kit

exit 0

