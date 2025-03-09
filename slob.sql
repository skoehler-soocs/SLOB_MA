-- 
-- This file is a part of SLOB - The Simple Database I/O Testing Toolkit for Oracle Database
--
-- Copyright (c) 1999-2017 Kevin Closson and Kevin Closson d.b.a. Peak Performance Systems
--
-- The Software
-- ------------
-- SLOB is a collection of software, configuration files and documentation (the "Software").
--
-- Use
-- ---
-- Permission is hereby granted, free of charge, to any person obtaining a copy of the Software, to
-- use the Software. The term "use" is defined as copying, viewing, modifying, executing and disclosing
-- information about use of the Software to third parties.
--
-- Redistribution
-- --------------
-- Permission to redistribute the Software to third parties is not granted. The Software           
-- is obtainable from kevinclosson.net/slob. Any redistribution of the Software to third parties
-- requires express written permission from Kevin Closson.
--
-- The copyright notices and permission notices shall remain in all copies of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
-- BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
-- USE OR OTHER DEALINGS IN THE SOFTWARE.


HOST ./mywait

-- SET SERVEROUTPUT OFF ;
SET SERVEROUTPUT ON   ;
SET VERIFY OFF;


DECLARE
v_default_schema_number PLS_INTEGER := '&1';
v_update_pct PLS_INTEGER := '&2';
v_max_loop_iterations PLS_INTEGER := '&3';
v_seconds_to_run PLS_INTEGER := '&4';
v_scale PLS_INTEGER := '&5';
v_work_unit PLS_INTEGER := '&6' ;
v_redo_stress  VARCHAR2(12) := '&7';
v_hot_schema_modulus PLS_INTEGER := '&8';
v_do_hotspot   VARCHAR(7) := '&9';
v_hotspot_mb  NUMBER := '&10';
v_hotspot_offset_mb NUMBER := '&11';
v_hotspot_modulus  PLS_INTEGER := '&12';

v_sleep_modulus PLS_INTEGER := '&13';
v_sleep_min NUMBER := '&14';
v_sleep_max NUMBER := '&15';
v_scan_query_pct PLS_INTEGER := '&16';
v_obfuscate VARCHAR(5)  := '&17';


v_hotspot_base NUMBER(15) := ( v_hotspot_offset_mb * 1024 * 1024 ) / 8192 ;
v_hotspot_blocks NUMBER(15) := ( v_hotspot_mb * 1024 * 1024 ) / 8192 ;

v_num_tmp NUMBER := 0;

v_loop_cnt PLS_INTEGER := 0;
v_rowcnt PLS_INTEGER := 0;
v_updates_cnt PLS_INTEGER := 0;
v_selects_cnt PLS_INTEGER := 0;

v_random_access_queries_cnt PLS_INTEGER := 0;
v_scan_queries_cnt PLS_INTEGER := 0;

v_do_scan_query BOOLEAN :=FALSE;
v_scan_query_quota  BOOLEAN := FALSE;
v_scan_workload_only BOOLEAN := FALSE;
v_random_workload_only BOOLEAN := FALSE;


v_random_block PLS_INTEGER := 1;
v_tmp PLS_INTEGER;
v_now PLS_INTEGER;
v_brick_wall PLS_INTEGER;

v_begin_time PLS_INTEGER;
v_end_time PLS_INTEGER;
v_total_time PLS_INTEGER;
v_begin_cpu_tm PLS_INTEGER;
v_end_cpu_tm PLS_INTEGER;
v_total_cpu_tm PLS_INTEGER;

v_do_sleeps BOOLEAN := FALSE;
v_loop_control BOOLEAN := FALSE;
v_update_quota BOOLEAN := FALSE;
v_select_only_workload BOOLEAN := FALSE;
v_update_only_workload BOOLEAN := FALSE;
v_do_update BOOLEAN := FALSE;
v_do_hot_schema BOOLEAN := FALSE;
v_stop_immediate BOOLEAN := FALSE;
v_sharing_schema BOOLEAN := FALSE;
v_seed VARCHAR2(128);
v_home_schema_str VARCHAR2(80);
v_scratch VARCHAR2(200) ;

v_cpu_pct NUMBER(6,3);
v_my_serial NUMBER(16);

BEGIN

v_home_schema_str := 'ALTER SESSION SET CURRENT_SCHEMA = user' || v_default_schema_number ;
EXECUTE IMMEDIATE v_home_schema_str; 


IF ( v_hot_schema_modulus != 0 ) THEN 
	v_do_hot_schema := TRUE;
END IF;

IF ( v_sleep_modulus != 0 )       THEN 
	v_do_sleeps := TRUE;
END IF;

IF ( v_max_loop_iterations > 0 )  THEN 
	v_loop_control := TRUE ;
END IF;

IF ( v_update_pct = 0 )           THEN 
	v_select_only_workload := TRUE;
END IF;

IF ( v_update_pct = 100 )         THEN 
	v_update_only_workload := TRUE;
END IF;

IF ( v_scan_query_pct = 0 ) 	THEN
	v_random_workload_only := TRUE;
END IF;

IF ( v_scan_query_pct = 100 ) 	THEN
	v_scan_workload_only := TRUE;
END IF;

v_seconds_to_run := v_seconds_to_run * 100 ;

SELECT ((10000000000 * (SID + SERIAL#)) + 1000000000000) INTO v_my_serial from v$session WHERE sid = ( select sys_context('userenv','sid') from dual);

-- v_seed := TO_CHAR(v_my_serial) || TO_CHAR(SYSTIMESTAMP,'YYYYDDMMHH24MISSFFFF');
-- DBMS_RANDOM.seed (val => v_seed);

v_begin_time := DBMS_UTILITY.GET_TIME();
v_now := v_begin_time ;
v_brick_wall := v_now + v_seconds_to_run ;
v_begin_cpu_tm := DBMS_UTILITY.GET_CPU_TIME();

----------------------------------------------------------------------------------------------------------------------
-- The following WHILE loop is the master work loop control
----------------------------------------------------------------------------------------------------------------------
WHILE ( v_now < v_brick_wall AND v_stop_immediate != TRUE )  LOOP

	IF ( v_do_sleeps = TRUE ) THEN --  This section deals with THINK_TIME
		IF ( MOD( v_random_block, v_sleep_modulus ) = 0 ) THEN
			v_num_tmp := ROUND (DBMS_RANDOM.VALUE(v_sleep_min, v_sleep_max) , 2 );
			-- dbms_output.put_line( 'step 1 ' || v_num_tmp  );
			DBMS_LOCK.SLEEP(v_num_tmp);
		END IF;	
	END IF;

	IF ( v_do_hot_schema = TRUE) THEN -- This section deals with Hot Schema
		IF ( MOD(v_loop_cnt, v_hot_schema_modulus) = 0 ) THEN
			EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = user1';
			v_sharing_schema := TRUE ;	
		ELSE
			IF ( v_sharing_schema = TRUE ) THEN 
				EXECUTE IMMEDIATE v_home_schema_str;
				v_sharing_schema := FALSE;
			END IF;
		END IF;	
	END IF;

	-- Choose the random block. The v_do_hotspot handler that follows can override.
	v_random_block := DBMS_RANDOM.VALUE(v_work_unit + 1, v_scale - v_work_unit);

	IF ( v_do_hotspot = 'TRUE' ) AND ( MOD(v_loop_cnt, v_hotspot_modulus ) = 0 ) THEN -- This section deals with Hot Spot
		-- v_random_block := DBMS_RANDOM.VALUE( v_hotspot_base  + v_work_unit + 1, v_hotspot_base + v_hotspot_blocks) ;
		v_random_block := DBMS_RANDOM.VALUE( v_hotspot_base + 1, v_hotspot_base + (v_hotspot_blocks - v_work_unit)) ;
		-- dbms_output.put_line( 'v_loop_cnt ' || v_loop_cnt || ' base ' || (v_hotspot_base  + v_work_unit + 1)  || ' zone ' || v_hotspot_blocks ||  '  Random block ' || v_random_block  );		
	END IF;

----------------------------------------------------------------------------------------------------------------------
-- The following section governs what the SQL execution will be (UPDATE or SELECT)
----------------------------------------------------------------------------------------------------------------------

	IF  ( v_select_only_workload = TRUE ) THEN 
		-- handle case where user specified zero pct updates (a SELECT-only workload)
		v_do_update := FALSE;
		v_update_quota := TRUE ;
	ELSE
		IF ( v_update_only_workload = TRUE ) THEN
			-- handle case where user specified 100% updates
			v_do_update := TRUE;
			v_update_quota := FALSE;
		ELSE			
			-- In this section we know we are not 100% SELECT, nor 100% UPDATES
			-- Work out whether this loop iteration is a SELECT or UPDATE here:
			IF ( v_update_quota = FALSE ) THEN
				-- Handle case where user has set UPDATE_PCT to a valid value
				--
				-- We are doing updates during this run and quota has not been met yet
				-- We still vacillate until update quota has been met

				IF ( MOD(v_random_block, 2) = 0 ) THEN
					v_do_update := TRUE;
				ELSE
					v_do_update := FALSE;
				END IF;
			ELSE
				-- UPDATE quota has been filled, force drain some SELECTs
				v_do_update := FALSE; 
			END IF;
		END IF;
	END IF;
		
----------------------------------------------------------------------------------------------------------------------
-- The type of SQL is now determined...execute it in the following section
----------------------------------------------------------------------------------------------------------------------

	IF ( v_do_update != TRUE ) THEN
		--
		-- Do a SELECT statement
		-- Work out scan or random
		IF  ( v_random_workload_only = TRUE ) THEN
                	-- handle case where user specified zero pct scan workload (SCAN_PCT = 0)
                	v_do_scan_query := FALSE;
                	v_scan_query_quota := TRUE ;
		ELSE
                	IF ( v_scan_workload_only = TRUE ) THEN
                        	-- handle case where user specified 100% scan workload (SCAN_PCT = 100)
                        	v_do_scan_query := TRUE;
                        	v_scan_query_quota := FALSE;
                	ELSE
                        	IF ( v_scan_query_quota = FALSE ) THEN
                                	-- Handle case where user specified valid, non-zero, SCAN_PCT
                                	-- IF ( MOD(v_random_block, 2) = 0 ) THEN
                                	IF ( MOD(v_loop_cnt, 2) = 0 ) THEN
                                        	v_do_scan_query := TRUE;
                                	ELSE
                                        	v_do_scan_query := FALSE;
                                	END IF;
                        	ELSE
                                	-- Scan quota has been filled, force drain some random access SELECTS
                                	v_do_scan_query := FALSE;
                        	END IF;
                	END IF;
		END IF;


		IF ( v_do_scan_query != TRUE ) THEN 
			SELECT COUNT(c2) INTO v_rowcnt 
			FROM cf1 
			WHERE ( custid > ( v_random_block - v_work_unit ) ) AND  (custid < v_random_block);

			v_random_access_queries_cnt := v_random_access_queries_cnt + 1;		
		ELSE
			SELECT COUNT(c2) INTO v_rowcnt FROM cf2;

                        v_scan_queries_cnt := v_scan_queries_cnt + 1;

			IF ( v_scan_queries_cnt >= v_scan_query_pct ) THEN
				v_scan_query_quota := TRUE;
			END IF;
		END IF;

		v_selects_cnt := v_selects_cnt + 1;   --increment the number of total selects
	ELSE
		--
		-- Do an UPDATE statement
		--

		v_my_serial := v_my_serial + v_loop_cnt ;

		user1.slobupdate( v_random_block, v_work_unit, v_redo_stress, v_my_serial, v_obfuscate);	
		--
		-- Increment count of UPDATES and set UPDATE quota flag if needed
		--
		v_updates_cnt := v_updates_cnt + 1;

		IF ( v_updates_cnt >= v_update_pct ) THEN
			v_update_quota := TRUE;	
		END IF;
	END IF ;
----------------------------------------------------------------------------------------------------------------------
--  At this point SQL has been executed. Finish this loop iteration with some housekeeping.
----------------------------------------------------------------------------------------------------------------------

	IF ( v_select_only_workload != TRUE ) AND (( v_updates_cnt + v_selects_cnt ) >=  100 ) THEN
		--
		-- Not a SELECT-only workload, and the global quota (UPDATES to SELECTS) is filled,
		-- so reset flags and counters before continuing 
		--
		v_update_quota := FALSE;
		v_updates_cnt := 0;
		v_selects_cnt := 0;
	END IF;

	IF ( v_random_workload_only != TRUE ) AND ( ( v_scan_queries_cnt + v_random_access_queries_cnt ) >=  100 ) THEN
		-- Not a random-only workload and global quota (RANDOM vs SCAN) is filled,
		-- so reset flags and counters
		v_scan_query_quota := FALSE;
		v_scan_queries_cnt := 0;
		v_random_access_queries_cnt := 0;
	END IF;

	v_loop_cnt := v_loop_cnt + 1 ;
	v_now := DBMS_UTILITY.GET_TIME();

        IF ( v_loop_control = TRUE ) AND  ( v_loop_cnt >= v_max_loop_iterations ) THEN
		-- If this is a fixed-iteration count test cycle and we've hit the number of
		-- iterations then set exit flag
                v_stop_immediate := TRUE ;
        END IF;
END LOOP;

v_end_time := v_now ;
v_now := DBMS_UTILITY.GET_TIME();
v_end_cpu_tm := DBMS_UTILITY.GET_CPU_TIME(); 

v_total_time := v_end_time - v_begin_time ;
v_total_cpu_tm := v_end_cpu_tm - v_begin_cpu_tm  ;
v_cpu_pct := ( v_total_cpu_tm / v_total_time ) * 100 ;
v_scratch := v_default_schema_number || '|' || v_total_time || '|' || v_total_cpu_tm || '|' || v_cpu_pct ;

END;
/
exit

