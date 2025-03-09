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

SET SERVEROUTPUT ON
DECLARE
  lat  INTEGER;
  iops INTEGER;
  mbps INTEGER;
BEGIN
   DBMS_RESOURCE_MANAGER.CALIBRATE_IO (1, 10, iops, mbps, lat);
 
  DBMS_OUTPUT.PUT_LINE ('max_iops = ' || iops);
  DBMS_OUTPUT.PUT_LINE ('latency  = ' || lat);
  DBMS_OUTPUT.PUT_LINE('max_mbps = ' || mbps);
END;
/
