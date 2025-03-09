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
#
# 20170118 - berx - initial changes for statspack ...

expon(){
local x="$1"
local e=0
local b=0

if ( echo "$x" | grep '+' > /dev/null 2>&1 )
then
        # Is expon
	b=`echo $x | sed 's/+.*$//g'`
        e=`echo $x | sed -e 's/^.*+0//g' -e 's/^.*+//g'`
	echo "$b $e" | awk '{ printf("%7.1f\n", $1 * ( 10 ^ $2 )) }'
else
	echo $x
fi
return 0
}

chomp () 
{ 
    local field="$1";
    if [ -z "$field" ]; then
        sed -e 's/[a-zA-Z\(\):]//g';
        return;
    else
        case "$field" in 
            "1")
                expon `sed -e 's/[->a-zA-Z\(\):]//g' | awk '{ print $1 }' `
            ;;
            "2")
                expon `sed -e 's/[->a-zA-Z\(\):]//g' | awk '{ print $2 }'` 
            ;;
            *)
                echo
            ;;
        esac;
    fi;
    return 0
}
commas () 
{ 
    sed 's/\,//g';
    return 0
}
dbcpu () 
{ 
    local f="$1";
    local tmp="";
    tmp=`egrep 'DB CPU.s|Background CPU.s' $f 2>/dev/null | chomp 1 | awk '{ x=x+$1}END{print x}' `;
    echo "$tmp";
    return 0
}

dbtm () 
{ 
    local f="$1";
    local tmp="";
    tmp=`egrep 'DB Time.s|Total DB Time .s' $f 2>/dev/null | head -1 | chomp 1`;
    echo "$tmp";
    return 0
}
del_cr () 
{ 
    tr -d '\r';
    return 0
}
get_exec_per_second () 
{ 
    local f="$1";
    local tmp="";
    tmp=`grep 'Executes.*:' $f 2>/dev/null 2>&1 | chomp 1 | print_int `;
    echo "$tmp";
    return 0
}
get_lio_per_second () 
{ 
    local f="$1";
    local tmp="";
    tmp=`grep 'Logical read.*:' $f 2>/dev/null | chomp 1 | print_int `;
    echo "$tmp";
    return 0
}
get_read_iops () 
{ 
    local f="$1";
    local tmp="";
    tmp=`grep 'physical read IO requests' $f | sed 's/^.*requests//g' 2>/dev/null `;
    echo "$tmp";
    return 0
}
get_read_mbs () 
{ 
    local f="$1";

    grep '^physical read total bytes' $f 2> /dev/null | head -1 | chomp 2 | awk '{ printf("%7.1f\n",$1 / (2^20) ) }'

    return 0
}
get_redo_mbs () 
{ 
    local f="$1";
    local x="";
    local tmp="";
    x=`grep 'Redo size.*:' $f 2>/dev/null | chomp 1`;
    tmp=`echo "scale=1 ; $x / 2^20" | bc -q`;
    echo "$tmp";
    return 0
}
get_runtime () 
{ 
    local f="$1";
    local tmp="";
    tmp=`grep 'Elapsed:' $f | head -1 | awk '{ printf("%d\n", $2 * 60 ) }'`;
    echo "$tmp";
    return 0
}
get_sesscnt_from_fname () 
{ 
    local fname="$1";
    local tmp="";
    tmp=`echo "$fname" | awk ' BEGIN { FS="." } { print $NF }'`;
    [[ "$tmp" = "txt" ]] && tmp="";
    echo "$tmp";
    return 0
}
get_top_event () 
{ 
    local f="$1";
    local tmp="";
    tmp=`cat $f | sed -n '/Top.*Foreground Events/,$p'| head -10 | sed '/^Top/,/^Event/d' | head -1`;
    if [ -z "$tmp" ] ; then # for statspack
      tmp=`cat $f | sed -n '/Foreground Wait Events/,$p'| head -10 | sed '/^.*oreg/,/^Event/d' | head -1`;
    fi
    echo "$tmp";
    return 0
}
get_wait_info () 
{ 
    local f="$1";
    local event_type="$2";
    local token="$3";
    local tmp="";
    local b="";
    local e="";
    if [ "$event_type" = "BG" ]; then
        b="Background Wait Event";
        e="Wait Event Histogram";
    else
        b="Foreground Wait Event";
        e="Background Wait Event";
    fi;
    rec=`cat $f 2>/dev/null | sed -n "/$b/,/$e/p" | sed  -e '/^[^a-zA-Z]/d' | grep "$token" | head -1 | commas 2> /dev/null 2>&1`;
    if ( ! echo "$rec" | grep "$token" > /dev/null 2>&1 ); then
        return 1;
    else
        rec=`echo "$rec" | sed "s/$token//g"`;
    fi;
    set - `echo "$rec"`;
    case "$#" in 
        6)
            echo "$1 $3"
        ;;
        5)
            echo "$1 $2"
        ;;
        *)
            return 1
        ;;
    esac;
    return 0
}
get_write_iops () 
{ 
    local f="$1";
    local tmp="";
    tmp=`grep 'physical write IO requests' $f | sed 's/^.*requests//g' 2>/dev/null `;
    echo "$tmp";
    return 0
}
get_write_mbs () 
{ 
    local f="$1";
    grep '^physical write total bytes' $f 2> /dev/null | head -1 | chomp | awk '{ 
printf("%6.0lf\n",  ( $2 / 2 ^ 20)   )
}';
    return 0
}
instance_activity_tuples () 
{ 
    local f="$1";
    cat $f 2> /dev/null | sed -n '/Instance Activity Stats/,$p';
    return 0
}
prep_file () 
{ 
    local infile=$1;
    local outfile=$2;
    cat $infile 2> /dev/null | del_cr | commas | sed '/^---/d' > $outfile;
    return 0
}
print_int () 
{ 
    awk '{ printf("%d\n",$1 ) }';
    return 0
}
process_wait_event_info () 
{ 
    local f="$1";
    local event_type="$2";
    local token="$3";
    local waits="";
    local secs="";
    local tmp="";
    local ret="";
    tmp=`get_wait_info "$f" "$event_type" "$token"`;
    ret=$?;
    if [ "$ret" -ne 0 ]; then
        echo "0";
        return 1;
    else
        set - `echo $tmp`;
        waits="$1";
        secs="$2";
        echo "$waits  $secs" | awk '{ printf("%8.0lf\n", ( $2 / $1 ) * 10^6  ) }';
    fi;
    return 0
}

#------Main Program Body
#@(#) awr_info.sh 2014.12.11 

tmpfile=.${$}${RANDOM}
origfile=""

echo "FILE|SESSIONS|ELAPSED|DB CPU|DB Tm|EXECUTES|LIO|PREADS|READ_MBS|PWRITES|WRITE_MBS|REDO_MBS|DFSR_LAT|DPR_LAT|DFPR_LAT|DFPW_LAT|LFPW_LAT|TOP WAIT|"

for file in $*
do

	origfile=$file
	num_sessions=`get_sesscnt_from_fname $origfile`
	prep_file $origfile $tmpfile
	file=$tmpfile

	elapsed=`get_runtime $file`

	#CPU
	dbcpu=`dbcpu $file`
	dbtm=`dbtm $file`

	pwrites=`get_write_iops $file | chomp 2 | print_int `
	preads=`get_read_iops $file | chomp 2 | print_int `

	top_event=`get_top_event $file`
	read_mbs=`get_read_mbs $file`
	write_mbs=`get_write_mbs $file`
	redo_mbs=`get_redo_mbs $file`
	executes=`get_exec_per_second $file`
	liops=`get_lio_per_second $file`


	# FOREGROUND
	dfsr_lat=`process_wait_event_info $file FG "db file sequential read"`
	dpr_lat=`process_wait_event_info $file FG "direct path read"`
	dfpr_lat=`process_wait_event_info $file FG "db file parallel read"`

	# BACKGROUND
	dfpw_lat=`process_wait_event_info $file BG "db file parallel write"`
	lfpw_lat=`process_wait_event_info $file BG "log file parallel write"`

	echo "$origfile|$num_sessions|$elapsed|$dbcpu|$dbtm|$executes|$liops|$preads|$read_mbs|$pwrites|$write_mbs|$redo_mbs|$dfsr_lat|$dpr_lat|$dfpr_lat|$dfpw_lat|$lfpw_lat|$top_event|"
done 

rm -f $tmpfile
