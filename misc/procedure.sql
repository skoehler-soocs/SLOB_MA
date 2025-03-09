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
--
-- SLOB 2.5.2.4
--

WHENEVER OSERROR EXIT FAILURE ;
WHENEVER SQLERROR EXIT SQL.SQLCODE ;


create or replace procedure user1.slobupdate (pv_random PLS_INTEGER, pv_work_unit PLS_INTEGER, pv_redo_stress VARCHAR2, pv_my_serial NUMBER, pv_obfuscate VARCHAR)
authid current_user
AS 
  v_mykey              varchar2(128);
  v_filler             varchar2(128);
  v_filler_chars       PLS_INTEGER;
  v_key_chars          PLS_INTEGER;

BEGIN
v_key_chars    := 9 ;
v_filler_chars := 128 - v_key_chars ;
v_mykey  := substr(to_char(pv_my_serial),1,v_key_chars) ;
v_filler := v_mykey || 'ZAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAAAAABBBBBBBBAAAAABBBBB';

IF ( pv_redo_stress = 'HEAVY' ) THEN                   -- slob.conf->REDO_STRESS=HEAVY
	IF ( pv_obfuscate = 'FALSE' ) THEN             -- $OBFUSCATE_COLUMNS=FALSE
		UPDATE cf1 SET
		c2  =  v_filler,
		c3  =  v_filler,
		c4  =  v_filler,
		c5  =  v_filler,
		c6  =  v_filler,
		c7  =  v_filler,
		c8  =  v_filler,
		c9  =  v_filler,
		c10  = v_filler,
		c11  = v_filler,
		c12  = v_filler,
		c13  = v_filler,
		c14 =  v_filler,
		c15 =  v_filler,
		c16 =  v_filler,
		c17 =  v_filler,
		c18 =  v_filler,
		c19 =  v_filler,
		c20 =  v_filler
		WHERE  custid >  ( pv_random - pv_work_unit ) AND  ( custid < pv_random);
		COMMIT;
	ELSE -- $OBFUSCATE_COLUMNS=TRUE
        	UPDATE cf1 SET
        	c2  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c3  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c4  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c5  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c6  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c7  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c8  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c9  =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c10  = v_mykey || dbms_random.string('X', v_filler_chars ),
        	c11  = v_mykey || dbms_random.string('X', v_filler_chars ),
        	c12  = v_mykey || dbms_random.string('X', v_filler_chars ),
        	c13  = v_mykey || dbms_random.string('X', v_filler_chars ),
        	c14 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c15 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c16 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c17 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c18 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c19 =  v_mykey || dbms_random.string('X', v_filler_chars ),
        	c20 =  v_mykey || dbms_random.string('X', v_filler_chars )
        	WHERE  custid >  ( pv_random - pv_work_unit ) AND  ( custid < pv_random);
        	COMMIT;
	END IF;
ELSE                                        -- slob.conf->REDO_STRESS=LITE
	IF ( pv_obfuscate = 'FALSE' ) THEN  -- $OBFUSCATE_COLUMNS=FALSE
		UPDATE cf1 SET
		c2  = v_filler,
		c20 = v_filler 
		WHERE  ( custid >  ( pv_random - pv_work_unit )) AND  (custid < pv_random);
		COMMIT;
	ELSE                                -- $OBFUSCATE_COLUMNS=TRUE
		UPDATE cf1 SET
		c2  = v_mykey || dbms_random.string('X', v_filler_chars ),
		c20 = v_mykey || dbms_random.string('X', v_filler_chars ) 
		WHERE  ( custid >  ( pv_random - pv_work_unit )) AND  (custid < pv_random);
		COMMIT;
	END IF;
END IF;
END slobupdate;
/
SHOW ERRORS

EXIT;
