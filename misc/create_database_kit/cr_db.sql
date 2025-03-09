-- DISCLAIMER OF WARRANTIES AND LIMITATION OF LIABILITY
-- The software is supplied "as is" and all use is at your own risk.  Kevin Closson, and Kevin Closson d.b.a
-- Peak Performance Systems disclaims all warranties of any kind, either express or implied, as to 
-- the software, including, but not limited to, implied warranties of fitness for a particular purpose, 
-- merchantability or non-infringement of proprietary rights.  Neither this agreement nor any documentation 
-- furnished under it is intended to express or imply any warranty that the operation of the software will 
-- be uninterrupted, timely, or error-free.  Under no circumstances shall Kevin Closson, nor Kevin Closson d.b.a
-- Peak Performance Systems be liable to any user for direct, indirect, incidental, consequential, special, or 
-- exemplary damages, arising from or relating to this agreement, the software, or user's use or misuse of the 
-- softwares.  Such limitation of liability shall apply whether the damages arise from the use or misuse of 
-- the software (including such damages incurred by third parties), or errors of the software.                   

spool createDB.lis
startup force exclusive nomount pfile=./create.ora


create database SLOB CONTROLFILE REUSE
SET DEFAULT BIGFILE TABLESPACE
maxinstances 1
maxdatafiles 1024
maxlogfiles 16
noarchivelog
datafile size 50M
-- _disk_sector_size_override = TRUE << this must be in create.ora for blocksize 4K
-- logfile SIZE 1G BLOCKSIZE 4096, SIZE 1G BLOCKSIZE 4096, SIZE 1G BLOCKSIZE 4096 , SIZE 1G BLOCKSIZE 4096
logfile SIZE 1G, SIZE 1G, SIZE 1G, SIZE 1G
/

alter tablespace SYSTEM autoextend on;
alter tablespace SYSAUX autoextend on;
set echo off

@?/rdbms/admin/catalog
@?/rdbms/admin/catproc

connect / as sysdba 

@?/sqlplus/admin/pupbld

-- create bigfile undo tablespace UNDOTBS1 datafile size 32G ;
create bigfile undo tablespace UNDOTBS1 datafile size 4G ;

create bigfile tablespace IOPS datafile size 1G nologging online 
permanent extent management local autoallocate  segment space management auto ;

alter tablespace IOPS autoextend on next 1G maxsize unlimited;

