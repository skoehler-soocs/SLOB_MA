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

if [ -z "$1" ]
then
	echo "Usage: ${0}: Script requires a single argument for init.ora file path"
	exit 1
else

	if [ ! -f "$1" ]
	then
		echo "FATAL: ${0}: \"$1\" no such file." 
		exit 1 
	fi

fi


export ADMIN_CONNECT_STRING="/ as sysdba"

source ./slob.conf

if [ -n "$ADMIN_SQLNET_SERVICE" ]
then
        export ADMIN_CONNECT_STRING="sys/${SYSDBA_PASSWD}@${ADMIN_SQLNET_SERVICE} as sysdba"
fi

sqlplus -L $ADMIN_CONNECT_STRING <<EOF
STARTUP FORCE PFILE=./${1}
EXIT;
EOF
