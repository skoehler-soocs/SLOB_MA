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


-- alter session set db_create_file_dest='+DATA';

set echo on
set timing on
drop tablespace IOPS including contents and datafiles;

create BIGFILE tablespace IOPS datafile size 1G 
NOLOGGING ONLINE PERMANENT EXTENT MANAGEMENT LOCAL AUTOALLOCATE SEGMENT SPACE MANAGEMENT AUTO ;

alter tablespace IOPS autoextend on next 200m maxsize unlimited;
exit;
