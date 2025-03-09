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

execute dbms_scheduler.set_attribute('WEEKNIGHT_WINDOW','RESOURCE_PLAN',''); 
execute dbms_scheduler.set_attribute('WEEKEND_WINDOW','RESOURCE_PLAN','');

execute dbms_scheduler.set_attribute('MONDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('TUESDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('WEDNESDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('THURSDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('FRIDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('SATURDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('SUNDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('WEEKNIGHT_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('WEEKEND_WINDOW','RESOURCE_PLAN','');

