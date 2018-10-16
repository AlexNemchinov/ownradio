-- Table: public.execution_start_time

   DROP TABLE IF EXISTS public.execution_start_time;

CREATE TABLE public.execution_start_time
(
  timeofday timestamp without time zone
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.execution_start_time
  OWNER TO postgres;

-- Table: public.rnd

   DROP TABLE IF EXISTS public.rnd;

CREATE TABLE public.rnd
(
  "?column?" double precision
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.rnd
  OWNER TO postgres;


-- Function: public.getnexttrack(uuid)

-- DROP FUNCTION public.getnexttrack(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrack(IN i_deviceid uuid)
  RETURNS TABLE(track character varying, methodid integer, useridrecommended character varying, txtrecommendedinfo character varying) AS
$BODY$
DECLARE
  i_userid UUID = i_deviceid; -- � ���������� �������� ���������� userid �� deviceid
BEGIN
  -- ��������� ����������, ���� ��� ��� �� ����������
  -- ���� ID ���������� ��� ��� � ��
  IF NOT EXISTS(SELECT recid
      FROM devices
      WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;

  -- ���������� trackid, ����������� ��� � character varying � methodid
  RETURN QUERY SELECT
       CAST((nexttrack.track) AS CHARACTER VARYING),
       nexttrack.methodid,
       CAST((nexttrack.useridrecommended) AS CHARACTER VARYING),
       nexttrack.txtrecommendedinfo
     FROM getnexttrackid_v10(i_deviceid) AS nexttrack;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrack(uuid)
  OWNER TO postgres;


  
-- Function: public.getnexttrackid(uuid)

-- DROP FUNCTION public.getnexttrackid(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid(i_deviceid uuid)
  RETURNS SETOF uuid AS
$BODY$
DECLARE
  i_userid UUID = i_deviceid;
BEGIN
  -- ��������� ����������, ���� ��� ��� �� ����������
  -- ���� ID ���������� ��� ��� � ��
  IF NOT EXISTS(SELECT recid
          FROM devices
          WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
                       i_userid,
                       'New user recname',
                       now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
                       i_deviceid,
                       i_userid,
                       'New device recname',
                       now();
  ELSE
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;

  RETURN QUERY
  SELECT tracks.recid
  FROM tracks
    LEFT JOIN
    ratings
      ON tracks.recid = ratings.trackid AND ratings.userid = i_userid
  WHERE ratings.ratingsum >= 0 OR ratings.ratingsum IS NULL
  ORDER BY RANDOM()
  LIMIT 1;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid(uuid)
  OWNER TO postgres;


  
-- Function: public.getnexttrackid_string(uuid)

-- DROP FUNCTION public.getnexttrackid_string(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_string(i_deviceid uuid)
  RETURNS SETOF character varying AS
$BODY$
BEGIN
  RETURN QUERY SELECT CAST(getnexttrackid(i_deviceid) AS CHARACTER VARYING);
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_string(uuid)
  OWNER TO postgres;


  
-- Function: public.getnexttrackid_v2(uuid)

-- DROP FUNCTION public.getnexttrackid_v2(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v2(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer) AS
$BODY$
DECLARE
	i_userid uuid = i_deviceid;
	rnd integer = (select trunc(random() * 10)); -- �������� ��������� ����� �� 0 �� 9
    o_methodid integer; -- id ������ ������ �����
BEGIN

  -- �������� ��������� ����

  -- � 9/10 ������� �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
  -- � ������������� ���������, �� ����������� ������������ �� ��������� �����
	IF (rnd > 1)
	THEN
		o_methodid = 2;
		RETURN QUERY
		SELECT trackid, o_methodid
          FROM ratings
          WHERE userid = i_userid
            AND lastlisten < localtimestamp - interval '1 day'
            AND ratingsum >= 0
          ORDER BY RANDOM()
          LIMIT 1;

		-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
		IF FOUND
	      THEN RETURN;
		END IF;
	END IF;

	-- � 1/10 ������ �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
	o_methodid = 3;
	RETURN QUERY
	SELECT recid, o_methodid
      FROM tracks
      WHERE recid NOT IN
		(SELECT trackid
		FROM ratings
		WHERE userid = i_userid)
      ORDER BY RANDOM()
      LIMIT 1;

  -- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
	IF FOUND
	THEN RETURN;
	END IF;

	-- ���� ���������� ������� ������� null, �������� ��������� ����
	o_methodid = 1;
	RETURN QUERY
	SELECT recid, o_methodid
	  FROM tracks
      ORDER BY RANDOM()
      LIMIT 1;
	RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v2(uuid)
  OWNER TO postgres;

  
-- Function: public.getnexttrackid_v3(uuid)

-- DROP FUNCTION public.getnexttrackid_v3(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v3(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer) AS
$BODY$
DECLARE
	i_userid   uuid = i_deviceid;
	rnd        integer = (select trunc(random() * 1001));
	o_methodid integer; -- id ������ ������ �����
    owntracks integer; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
BEGIN
	-- �������� ��������� ����

	-- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
	owntracks = (SELECT COUNT(*) FROM (
		SELECT * FROM ratings
			WHERE userid = i_userid
					AND ratingsum >=0
			LIMIT 900) AS count) ;

	-- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
	-- � ������������� ���������, �� ����������� ������������ �� ��������� �����

	IF (rnd < owntracks)
	THEN
		o_methodid = 2; -- ����� ������ �� ����� ������
		RETURN QUERY
		SELECT trackid, o_methodid
          FROM ratings
          WHERE userid = i_userid
                AND lastlisten < localtimestamp - interval '1 day'
                AND ratingsum >= 0
		ORDER BY RANDOM()
		LIMIT 1;

		-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
		IF FOUND
		THEN RETURN;
		END IF;
	END IF;

	-- � 1/10 ������ �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
	o_methodid = 3; -- ����� ������ �� �������������� ������
	RETURN QUERY
	SELECT recid, o_methodid
      FROM tracks
      WHERE recid NOT IN
            (SELECT trackid
             FROM ratings
             WHERE userid = i_userid)
    ORDER BY RANDOM()
	LIMIT 1;

	-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
	IF FOUND
	  THEN RETURN;
	END IF;

	-- ���� ���������� ������� ������� null, �������� ��������� ����
	o_methodid = 1; -- ����� ������ ���������� �����
	RETURN QUERY
	SELECT recid, o_methodid
      FROM tracks
      ORDER BY RANDOM()
    LIMIT 1;
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v3(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v5(uuid)

-- DROP FUNCTION public.getnexttrackid_v5(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v5(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer) AS
$BODY$
DECLARE
	i_userid   UUID = i_deviceid;
	rnd        INTEGER = (SELECT trunc(random() * 1001));
	o_methodid INTEGER; -- id ������ ������ �����
	owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
BEGIN
	-- �������� ��������� ����

	-- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
	owntracks = (SELECT COUNT(*)
				 FROM (
						  SELECT *
						  FROM ratings
						  WHERE userid = i_userid
								AND ratingsum >= 0
						  LIMIT 900) AS count);

	-- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
	-- � ������������� ���������, �� ����������� ������������ �� ��������� �����

	IF (rnd < owntracks)
	THEN
		o_methodid = 2; -- ����� ������ �� ����� ������
		RETURN QUERY
		SELECT
			trackid,
			o_methodid
		FROM ratings
		WHERE userid = i_userid
			  AND lastlisten < localtimestamp - INTERVAL '1 day'
			  AND ratingsum >= 0
			  AND (SELECT isexist
				   FROM tracks
				   WHERE recid = trackid) = 1
			  AND ((SELECT length
					FROM tracks
					WHERE recid = trackid) >= 120
				   OR (SELECT length
					   FROM tracks
					   WHERE recid = trackid) IS NULL)
			  AND ((SELECT iscensorial
					FROM tracks
					WHERE recid = trackid) IS NULL
				   OR (SELECT iscensorial
					   FROM tracks
					   WHERE recid = trackid) != 0)
			  AND trackid NOT IN (SELECT trackid
								  FROM downloadtracks
								  WHERE reccreated > localtimestamp - INTERVAL '1 day')
		ORDER BY RANDOM()
		LIMIT 1;

		-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
		IF FOUND
		THEN RETURN;
		END IF;
	END IF;

	-- ���� rnd ������ ���������� "�����" ������ - �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
	o_methodid = 3; -- ����� ������ �� �������������� ������
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE recid NOT IN
		  (SELECT trackid
		   FROM ratings
		   WHERE userid = i_userid)
		  AND isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
		  AND recid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
	ORDER BY RANDOM()
	LIMIT 1;

	-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
	IF FOUND
	THEN RETURN;
	END IF;

	-- ���� ���������� ������� ������� null, �������� ��������� ����
	o_methodid = 1; -- ����� ������ ���������� �����
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
	ORDER BY RANDOM()
	LIMIT 1;
	RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v5(uuid)
  OWNER TO postgres;
  
  
  
-- Function: public.getnexttrackid_v6(uuid)

-- DROP FUNCTION public.getnexttrackid_v6(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v6(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer) AS
$BODY$
DECLARE
	i_userid   UUID = i_deviceid;
	rnd        INTEGER = (SELECT trunc(random() * 1001));
	o_methodid INTEGER; -- id ������ ������ �����
	owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
	arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
BEGIN
	-- �������� ��������� ����

	-- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
	owntracks = (SELECT COUNT(*)
				 FROM (
						  SELECT *
						  FROM ratings
						  WHERE userid = i_userid
								AND ratingsum >= 0
						  LIMIT 900) AS count);

	-- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
	-- � ������������� ���������, �� ����������� ������������ �� ��������� �����

	IF (rnd < owntracks)
	THEN
		o_methodid = 2; -- ����� ������ �� ����� ������
		RETURN QUERY
		SELECT
			trackid,
			o_methodid
		FROM ratings
		WHERE userid = i_userid
			  AND lastlisten < localtimestamp - INTERVAL '1 day'
			  AND ratingsum >= 0
			  AND (SELECT isexist
				   FROM tracks
				   WHERE recid = trackid) = 1
			  AND ((SELECT length
					FROM tracks
					WHERE recid = trackid) >= 120
				   OR (SELECT length
					   FROM tracks
					   WHERE recid = trackid) IS NULL)
			  AND ((SELECT iscensorial
					FROM tracks
					WHERE recid = trackid) IS NULL
				   OR (SELECT iscensorial
					   FROM tracks
					   WHERE recid = trackid) != 0)
			  AND trackid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
		ORDER BY RANDOM()
		LIMIT 1;

		-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
		IF FOUND
		THEN RETURN;
		END IF;
	END IF;

	-- ���� rnd ������ ���������� "�����" ������ - ����������� ���� �� ������ ������������ � ���������� 
	-- ������������� �������� ��������� � ���������� ��������� �������������

	-- ������� ���� ������������� � ��������������� ������������� �������� ��������� ��� i_userid
	-- ������������ �� �������� �������������
	arrusers = (SELECT ARRAY (SELECT CASE WHEN userid1 = i_userid THEN userid2
							WHEN userid2 = i_userid THEN userid1
							ELSE NULL
						END
						FROM ratios
						WHERE userid1 = i_userid OR userid2 = i_userid
							AND ratio >= 0
						ORDER BY ratio DESC
						));
	-- �������� ������������ i, � ������� � ���� ������������ �����������. ����� ��� ������ ���� ���� 
	-- � ������������ ��������� �������������, �� ����������� ��� ������������ ������������� i_userid. 
	-- ���� ������������� ������ - ����� ���������� ������������ � ���������� ������������� �� ����������.
	FOR i IN 1.. (SELECT COUNT (*) FROM unnest(arrusers)) LOOP
		o_methodid = 4; -- ����� ������ �� ��������������� ������
		RETURN QUERY
		SELECT
			trackid,
			o_methodid
			FROM ratings
			WHERE userid = arrusers[i]
				AND ratingsum > 0
				AND trackid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
				AND trackid NOT IN (SELECT trackid 
							FROM downloadtracks
							WHERE deviceid = i_deviceid
								AND reccreated > localtimestamp - INTERVAL '1 day')
				AND (SELECT isexist
					   FROM tracks
					   WHERE recid = trackid) = 1
				AND ((SELECT length
						FROM tracks
						WHERE recid = trackid) >= 120
					   OR (SELECT length
						   FROM tracks
						   WHERE recid = trackid) IS NULL)
				AND ((SELECT iscensorial
						FROM tracks
						WHERE recid = trackid) IS NULL
					   OR (SELECT iscensorial
						   FROM tracks
						   WHERE recid = trackid) != 0)
			ORDER BY ratingsum DESC
			LIMIT 1;
	-- ���� ����� ��� ������������� - ������� �� �������
		IF found THEN
		RETURN;
		END IF;
	END LOOP;
	
	-- ��� ���������� ������������, �������� ��������� ���� �� �������������� ������ � ��������������� 
	-- ��������� ����� ������������� �� ������ ������.
	FOR i IN 1.. (SELECT COUNT (*) FROM unnest(arrusers)) LOOP
		o_methodid = 5; -- ����� ������ �� �������������� ������ � ��������������� ��������� ����� ������������� �� ������ ������
		RETURN QUERY
		SELECT
			recid,
			o_methodid
			FROM tracks
			WHERE recid NOT IN (SELECT trackid FROM ratings WHERE userid = arrusers[i] AND ratingsum < 0)
				AND recid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
				AND isexist = 1
				AND (iscensorial IS NULL OR iscensorial != 0)
				AND (length > 120 OR length IS NULL)
				AND recid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
			ORDER BY RANDOM()
			LIMIT 1;
	-- ���� ����� ��� ������������� - ������� �� �������			
		IF found THEN
		RETURN;
		END IF;
	END LOOP;

	-- ���� ����� ������ ��� - �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
	o_methodid = 3; -- ����� ������ �� �������������� ������
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE recid NOT IN
		  (SELECT trackid
		   FROM ratings
		   WHERE userid = i_userid)
		  AND isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
		  AND recid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
	ORDER BY RANDOM()
	LIMIT 1;

	-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
	IF FOUND
	THEN RETURN;
	END IF;

	-- ���� ���������� ������� ������� null, �������� ��������� ����
	o_methodid = 1; -- ����� ������ ���������� �����
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
	ORDER BY RANDOM()
	LIMIT 1;
	RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v6(uuid)
  OWNER TO postgres;

  
-- Function: public.registertrack(uuid, character varying, character varying, uuid)

-- DROP FUNCTION public.registertrack(uuid, character varying, character varying, uuid);

CREATE OR REPLACE FUNCTION public.registertrack(
    i_trackid uuid,
    i_localdevicepathupload character varying,
    i_path character varying,
    i_deviceid uuid)
  RETURNS boolean AS
$BODY$
DECLARE
  i_userid    UUID = i_deviceid;
  i_historyid UUID;
  i_ratingid  UUID;
BEGIN
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  SELECT uuid_generate_v4()
  INTO i_historyid;
  SELECT uuid_generate_v4()
  INTO i_ratingid;

  --
  -- ������� ��������� ������ � ����� � ������� ������ � ������ ������������� ������ �
  -- ������� ���������� ������������� � ���������. ���� ������������, ������������ ����
  -- ��� � ����, �� �� ����������� � ������� �������������.
  --

  -- ��������� ����������, ���� ��� ��� �� ����������
  -- ���� ID ���������� ��� ��� � ��
  IF NOT EXISTS(SELECT recid
          FROM devices
          WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;

  -- ��������� ���� � ���� ������
  INSERT INTO tracks (recid, localdevicepathupload, path, deviceid, reccreated, iscensorial, isexist)
  VALUES (i_trackid, i_localdevicepathupload, i_path, i_deviceid, now(), 2, 1);

  -- ��������� ������ � ������������� ����� � ������� ������� �������������
  INSERT INTO histories (recid, deviceid, trackid, isListen, lastListen, reccreated)
  VALUES (i_historyid, i_deviceid, i_trackid, 1, now(), now());

  -- ��������� ������ � ������� ���������
  INSERT INTO ratings (recid, userid, trackid, lastListen, ratingsum, reccreated)
  VALUES (i_ratingid, i_userid, i_trackid, now(), 1, now());

  RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.registertrack(uuid, character varying, character varying, uuid)
  OWNER TO postgres;

  
-- Function: public.selectdownloadhistory(uuid)

-- DROP FUNCTION public.selectdownloadhistory(uuid);

CREATE OR REPLACE FUNCTION public.selectdownloadhistory(IN i_deviceid uuid)
  RETURNS TABLE(recid uuid, reccreated timestamp without time zone, recname character varying, recupdated timestamp without time zone, deviceid uuid, trackid uuid, isstatisticback integer) AS
$BODY$
  BEGIN
    -- ������� ������ ������ �� ������� �� ���� ������ ������� ������������� ��� ������� ����������
    RETURN QUERY  SELECT * FROM downloadtracks
    WHERE 
      downloadtracks.trackid NOT IN
        (SELECT histories.trackid FROM histories WHERE histories.deviceid = i_deviceid)
        AND downloadtracks.deviceid = i_deviceid;

  END;
  $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.selectdownloadhistory(uuid)
  OWNER TO postgres;
  
-- Function: public.calculateratios()

-- DROP FUNCTION public.calculateratios();

CREATE OR REPLACE FUNCTION public.calculateratios()
  RETURNS boolean AS
$BODY$
DECLARE
  -- ��������� ������ � ������ ��� ����
    curs1 CURSOR FOR SELECT * FROM(
        -- ������������ ������� ������������� �������� ��������� ��� ������ ���� �������������
        SELECT r.userid as userid01, r2.userid as userid02, 
              SUM(r.ratingsum * r2.ratingsum) as s
      --  SUM(CASE WHEN r.ratingsum > 0 AND r2.ratingsum > 0 THEN r.ratingsum * r2.ratingsum
--          WHEN r.ratingsum < 0 AND r2.ratingsum < 0 THEN 0
--          ELSE r.ratingsum * r2.ratingsum
--          END) as S
        FROM ratings r
            INNER JOIN ratings r2 ON r.trackid = r2.trackid
               AND r.userid != r2.userid
        WHERE r.ratingsum > 0 AND r2.ratingsum > 0 -- ���� ������ �� ��������� ����������� �����
        GROUP BY r.userid, r2.userid
        ) AS cursor1;
  cuser1 uuid;
  cuser2 uuid;
  cratio integer;
BEGIN
  DROP TABLE IF EXISTS temp_ratio;
  CREATE TEMP TABLE temp_ratio(userid1 uuid, userid2 uuid, ratio integer);

  OPEN curs1; -- ��������� ������
  LOOP -- � ����� �������� �� ������� ���������� ������� �������
    FETCH curs1 INTO cuser1, cuser2, cratio;

    IF NOT FOUND THEN EXIT; -- ���� ������ ��� - �������
    END IF;
    -- ���� ��� ������ ���� ������������� ��� ������� ����������� - ����������, ����� - ���������� �� ��������� �������
    --IF NOT EXISTS (SELECT * FROM temp_ratio WHERE userid1 = cuser2 AND userid2 = cuser1 OR userid1 = cuser1 AND userid2 = cuser2) THEN
      INSERT INTO temp_ratio(userid1, userid2, ratio)
      VALUES (cuser1, cuser2, cratio);
    --END IF;
  END LOOP;
  CLOSE curs1; -- ��������� ������

  -- ��������� ��������� ������������ � ������� ratios
  UPDATE ratios SET ratio = temp_ratio.ratio, recupdated = now() FROM temp_ratio
  WHERE (ratios.userid1 = temp_ratio.userid1 AND ratios.userid2 = temp_ratio.userid2);
--      OR (ratios.userid1 = temp_ratio.userid2 AND ratios.userid2 = temp_ratio.userid1);

  -- ���� � ratios ������ ��� �������������, ��� �� ��������� ������� - ��������� ����������� ������
  --IF (SELECT COUNT(*) FROM ratios) < (SELECT COUNT(*) FROM temp_ratio) THEN
--    INSERT INTO ratios (userid1, userid2, ratio, reccreated)
--      (SELECT tr.userid1, tr.userid2, tr.ratio, now()  FROM temp_ratio AS tr
--        LEFT OUTER JOIN ratios AS rr ON tr.userid1 = rr.userid1 AND tr.userid2 = rr.userid2 OR tr.userid1 = rr.userid2 AND tr.userid2 = rr.userid1
--      WHERE rr.userid1 IS NULL OR rr.userid2 IS NULL
--      );
  --END IF;
  INSERT INTO ratios (userid1, userid2, ratio, reccreated)
  (SELECT temp_ratio.userid1,temp_ratio.userid2, temp_ratio.ratio, now() 
    FROM temp_ratio
    LEFT OUTER JOIN ratios ON 
      temp_ratio.userid1 = ratios.userid1 AND temp_ratio.userid2 = ratios.userid2
    WHERE ratios.userid1 IS NULL OR ratios.userid2 IS NULL
  );
  RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.calculateratios()
  OWNER TO postgres;


  
-- Function: public.updateratios(uuid)

-- DROP FUNCTION public.updateratios(uuid);

CREATE OR REPLACE FUNCTION public.updateratios(i_userid uuid)
  RETURNS boolean AS
$BODY$
-- ������� ��������� ������� ������������� �������� ��������� ��� ���� �������������, ������������ �� �� �����, ��� � i_userid
DECLARE
  cuser1 uuid;
  cuser2 uuid;
  cratio integer;
BEGIN

--  RETURN true;
  
  DROP TABLE IF EXISTS temp_ratio;
  CREATE TEMP TABLE temp_ratio(userid1 uuid, userid2 uuid, ratio integer);

  -- ������������ ������� ������������� �������� ��������� ��� ������ ���� �������������
  INSERT INTO temp_ratio(userid1, userid2, ratio)
      (SELECT r.userid as userid01, r2.userid as userid02, --SUM(r.ratingsum * r2.ratingsum) as s
        -- ������� ����� ������������ � ������ ����� ��������������: ratingsum<0 => weight=1, ratingsum>0 => weight=3
        -- SUM(CASE WHEN r.ratingsum > 0 AND r2.ratingsum > 0 THEN r.ratingsum * r2.ratingsum * 3

        SUM(r.ratingsum * r2.ratingsum) as S
        -- ���� ������ �� ��������� ����������� ����� ������, ������� ������� case ���� �������� �� �������� � ����� where
        -- SUM(CASE WHEN r.ratingsum > 0 AND r2.ratingsum > 0 THEN r.ratingsum * r2.ratingsum
--          WHEN r.ratingsum < 0 AND r2.ratingsum < 0 THEN 0
--          ELSE r.ratingsum * r2.ratingsum
--          END) as S
        FROM ratings r
          INNER JOIN ratings r2 ON r.trackid = r2.trackid
               AND r.userid != r2.userid
               AND ((r.userid = i_userid AND r2.userid IN (SELECT recid FROM users WHERE experience >= 10)) 
                OR (r2.userid = i_userid AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)))
        WHERE r.ratingsum > 0 AND r2.ratingsum > 0
        GROUP BY r.userid, r2.userid);

  -- ��������� ratio, ���� ���� ������������� ��� ���� � �������
  UPDATE ratios SET ratio = temp_ratio.ratio, recupdated = now() FROM temp_ratio
    WHERE ratios.userid1 = temp_ratio.userid1 AND ratios.userid2 = temp_ratio.userid2;

  -- ��������� ������ ��� ����� ���� � ��������������
  INSERT INTO ratios (userid1, userid2, ratio, reccreated)
    (SELECT temp_ratio.userid1,temp_ratio.userid2, temp_ratio.ratio, now() 
      FROM temp_ratio
      LEFT OUTER JOIN ratios ON 
        temp_ratio.userid1 = ratios.userid1 AND temp_ratio.userid2 = ratios.userid2
      WHERE ratios.userid1 IS NULL OR ratios.userid2 IS NULL
    );

RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.updateratios(uuid)
  OWNER TO postgres;
  
  -- Function: getnexttrackid_v7(uuid)

-- DROP FUNCTION getnexttrackid_v7(uuid);

CREATE OR REPLACE FUNCTION getnexttrackid_v7(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer) AS
$BODY$

-- ������� ������ ���������� ����� ������������
-- � ������ ������������ �� ������ �������������

DECLARE
	i_userid   UUID = i_deviceid;
	rnd        INTEGER = (SELECT trunc(random() * 1001));
	o_methodid INTEGER; -- id ������ ������ �����
	owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
	arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
	exceptusers uuid ARRAY; -- ������ ������������� ��� i_userid � �������� �� ���� ����������� �� ������
BEGIN
	-- �������� ��������� ����

	-- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
	owntracks = (SELECT COUNT(*)
				 FROM (
						  SELECT *
						  FROM ratings
						  WHERE userid = i_userid
								AND ratingsum >= 0
						  LIMIT 900) AS count);

	-- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
	-- � ������������� ���������, �� ����������� ������������ �� ��������� �����

	IF (rnd < owntracks)
	THEN
		o_methodid = 2; -- ����� ������ �� ����� ������
		RETURN QUERY
		SELECT
			trackid,
			o_methodid
		FROM ratings
		WHERE userid = i_userid
			  AND lastlisten < localtimestamp - INTERVAL '1 day'
			  AND ratingsum >= 0
			  AND (SELECT isexist
				   FROM tracks
				   WHERE recid = trackid) = 1
			  AND ((SELECT length
					FROM tracks
					WHERE recid = trackid) >= 120
				   OR (SELECT length
					   FROM tracks
					   WHERE recid = trackid) IS NULL)
			  AND ((SELECT iscensorial
					FROM tracks
					WHERE recid = trackid) IS NULL
				   OR (SELECT iscensorial
					   FROM tracks
					   WHERE recid = trackid) != 0)
			  AND trackid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
		ORDER BY RANDOM()
		LIMIT 1;

		-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
		IF FOUND
		THEN RETURN;
		END IF;
	END IF;

	-- ���� rnd ������ ���������� "�����" ������ - ����������� ���� �� ������ ������������ � ���������� 
	-- ������������� �������� ��������� � ���������� ��������� �������������

	-- ������� ���� ������������� � ��������������� ������������� �������� ��������� ��� i_userid
	-- ������������ �� �������� �������������
	arrusers = (SELECT ARRAY (SELECT CASE WHEN userid1 = i_userid THEN userid2
							WHEN userid2 = i_userid THEN userid1
							ELSE NULL
							END
						FROM ratios
						WHERE userid1 = i_userid OR userid2 = i_userid
							AND ratio >= 0
						ORDER BY ratio DESC
						));
	-- �������� ������������ i, � ������� � ���� ������������ �����������. ����� ��� ������ ���� ���� 
	-- � ������������ ��������� �������������, �� ����������� ��� ������������ ������������� i_userid. 
	-- ���� ������������� ������ - ����� ���������� ������������ � ���������� ������������� �� ����������.
	FOR i IN 1.. (SELECT COUNT (*) FROM unnest(arrusers)) LOOP
		o_methodid = 4; -- ����� ������ �� ��������������� ������
		RETURN QUERY
		SELECT
			trackid,
			o_methodid
			FROM ratings
			WHERE userid = arrusers[i]
				AND ratingsum > 0
				AND trackid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
				AND trackid NOT IN (SELECT trackid 
							FROM downloadtracks
							WHERE deviceid = i_deviceid 
								AND reccreated > localtimestamp - INTERVAL '1 day')
				AND (SELECT isexist
					   FROM tracks
					   WHERE recid = trackid) = 1
				AND ((SELECT length
						FROM tracks
						WHERE recid = trackid) >= 120
					   OR (SELECT length
						   FROM tracks
						   WHERE recid = trackid) IS NULL)
				AND ((SELECT iscensorial
						FROM tracks
						WHERE recid = trackid) IS NULL
					   OR (SELECT iscensorial
						   FROM tracks
						   WHERE recid = trackid) != 0)
			ORDER BY ratingsum DESC
			LIMIT 1;
	-- ���� ����� ��� ������������� - ������� �� �������
		IF found THEN
		RETURN;
		END IF;
	END LOOP;
	
	-- ��� ���������� ������������, �������� ��������� ���� �� �������������� ������ � ���������������
	-- ��������� ����� ������������� � �������� �� ���� ����������� �� ������.
	exceptusers = (SELECT ARRAY (
				SELECT * FROM (
					SELECT recid FROM users WHERE recid != i_userid
						EXCEPT
						(SELECT CASE WHEN userid1 = i_userid THEN userid2
							 WHEN userid2 = i_userid THEN userid1
							 ELSE NULL
							 END
							FROM ratios WHERE userid1 = i_userid OR userid2 = i_userid)
				) AS us
			ORDER BY RANDOM()
			)
		);
	FOR i IN 1.. (SELECT COUNT (*) FROM unnest(exceptusers)) LOOP
		o_methodid = 6; -- ����� ������ �� �������������� ������ � ��������������� ��������� ����� ������������� � �������� �� ���� �����������
		RETURN QUERY 
		SELECT
			recid,
			o_methodid
		FROM tracks
		WHERE recid IN (SELECT trackid FROM ratings WHERE userid = exceptusers[i] AND ratingsum >= 0)
			  AND recid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
			  AND isexist = 1
			  AND (iscensorial IS NULL OR iscensorial != 0)
			  AND (length > 120 OR length IS NULL)
			  AND recid NOT IN (SELECT trackid
					FROM downloadtracks
					WHERE reccreated > localtimestamp - INTERVAL '1 day')
		ORDER BY RANDOM()
		LIMIT 1;
		-- ���� ����� ��� ������������� - ������� �� �������
		IF found THEN
			RETURN;
		ELSE 
		
		END IF;
	END LOOP;

	-- ���� ����� ������ ��� - �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
	o_methodid = 3; -- ����� ������ �� �������������� ������
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE recid NOT IN
		  (SELECT trackid
		   FROM ratings
		   WHERE userid = i_userid)
		  AND isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
		  AND recid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE reccreated > localtimestamp - INTERVAL '1 day')
	ORDER BY RANDOM()
	LIMIT 1;

	-- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
	IF FOUND
	THEN RETURN;
	END IF;

	-- ���� ���������� ������� ������� null, �������� ��������� ����
	o_methodid = 1; -- ����� ������ ���������� �����
	RETURN QUERY
	SELECT
		recid,
		o_methodid
	FROM tracks
	WHERE isexist = 1
		  AND (iscensorial IS NULL OR iscensorial != 0)
		  AND (length > 120 OR length IS NULL)
	ORDER BY RANDOM()
	LIMIT 1;
	RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION getnexttrackid_v7(uuid)
  OWNER TO "postgres";


-- Function: public.getrecommendedtrackid_v1(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v1(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v1(in_userid uuid)
  RETURNS uuid AS
$BODY$

DECLARE
preferenced_track uuid;

BEGIN
  -- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
  -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
  -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid INTO preferenced_track
    --tracks.recid, table2.sum_rate, tracks.localdevicepathupload, tracks.path
        FROM tracks
        INNER JOIN (
          --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
          --������� �� ���
          SELECT trackid, SUM(track_rating) AS sum_rate
          FROM(
            --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
            --� ��������, ���������� �� �� �����������
            SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
            FROM ratings


              --------------------------------------------------
              ---------------����� INNER JOIN-------------------
              --------------------------------------------------

              INNER JOIN
              (
                --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                --� �������� � UUID'�� ���� ���������.
                --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                --�������� ������������
                SELECT COALESCE(associated_experts.ratio, 1) AS ratio, all_experts.userid AS expert_id
                FROM
                (
                  --������� ������������ ������� ������������ � ���-���� �� ���������
                  --� UUID'� ���� ���������
                  SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                  FROM ratios
                  WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience = 10)
                ) AS associated_experts
                RIGHT JOIN 
                (
                  --������� UUID'� ���� ���������
                  SELECT recid AS userid
                  FROM users
                  WHERE experience = 10
                ) AS all_experts
                ON associated_experts.userid = all_experts.userid
              ) AS experts_ratios
              ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
              AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
              




              
              --------------------------------------------------
              --------------������ INNER JOIN-------------------
              --------------------------------------------------
              
              -- INNER JOIN ratios
--              --�������� �������� ������ � ��� �������������, � ������� ���� �����������
--              --� �������� � ������� ratios (����������� ���������� ������), �������� �������
--              --� ����� �������
--              ON ((ratings.userid = ratios.userid2 AND ratios.userid1 = in_userid)
--                -- ����� � ������
--                OR (ratings.userid = ratios.userid1 AND ratios.userid2 = in_userid))

 --             AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
 --             AND ratios.ratio > 0 --������� �������� ������, ������ � ������������� � ������������� ������������� ���������� ������ � ��������




              
          ) AS TracksRatings
          GROUP BY trackid
          ORDER BY sum_rate DESC
        ) AS table2
        ON tracks.recid = table2.trackid
        AND tracks.isexist = 1 --���� ������ ������������ �� �������
        AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
        AND tracks.length >= 120
        --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� �������
        AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                     WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
        AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
        ORDER BY table2.sum_rate DESC
           --���������� �� ������� ������� ����� ��� �������, ����� �������� ����� ������ � ��������� table2.sum_rate,
           --� ����� ������� ���� ���������� ������� �������� � ������������������ ������ ������
           --,tracks.recid
           ,random()
        LIMIT 1;
  RETURN preferenced_track;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.getrecommendedtrackid_v1(uuid)
  OWNER TO postgres;


-- Function: public.get_user_tracks_preference(uuid)

-- DROP FUNCTION public.get_user_tracks_preference(uuid);

CREATE OR REPLACE FUNCTION public.get_user_tracks_preference(IN in_userid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_track_sum_rate bigint, rn_localdevicepathupload character varying, rn_path character varying) AS
$BODY$

DECLARE 
rnd DOUBLE PRECISION;

BEGIN
RETURN QUERY (
  -- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
    -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
    -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid AS track_id, tracks_sum_rates.sum_rate AS track_sum_rate, tracks.localdevicepathupload, tracks.path-- INTO preferenced_track
    --tracks.recid, tracks_sum_rates.sum_rate, tracks.localdevicepathupload, tracks.path
          FROM tracks
          INNER JOIN (
            --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
            --������� �� ���
            SELECT trackid, SUM(track_rating) AS sum_rate
            FROM(
              --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
              --� ��������, ���������� �� �� �����������
              SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
              FROM ratings
                INNER JOIN
                (
                  --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                  --� �������� � UUID'�� ���� ���������.
                  --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                  --�������� ������������
                  SELECT COALESCE(associated_experts.ratio, 1) AS ratio, all_experts.userid AS expert_id
                  FROM
                  (
                    --������� ������������ ������� ������������ � ���-���� �� ���������
                    --� UUID'� ���� ���������
                    SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                    FROM ratios
                    WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience >= 10)
                  ) AS associated_experts
                  RIGHT JOIN 
                  (
                    --������� UUID'� ���� ���������
                    SELECT recid AS userid
                    FROM users
                    WHERE experience >= 10
                  ) AS all_experts
                  ON associated_experts.userid = all_experts.userid
                ) AS experts_ratios
                ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
                AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
                AND experts_ratios.ratio > 0 --������� �������� ������, ������ � ������������� � ������������� ������������� ���������� ������ � ��������
            ) AS tracks_ratings
            GROUP BY trackid
            ORDER BY sum_rate DESC
          ) AS tracks_sum_rates
          ON tracks.recid = tracks_sum_rates.trackid
          AND tracks.isexist = 1 --���� ������ ������������ �� �������
          AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
          AND tracks.length >= 120
          --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� �������
          AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                 WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
          AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
          ORDER BY tracks_sum_rates.sum_rate DESC
          );
        
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.get_user_tracks_preference(uuid)
  OWNER TO postgres;



-- Function: public.getlastdevices()

-- DROP FUNCTION public.getlastdevices();

CREATE OR REPLACE FUNCTION public.getlastdevices()
  RETURNS TABLE(recid character varying) AS
$BODY$
BEGIN

  RETURN QUERY SELECT CAST((dev.recid) AS CHARACTER VARYING)
         FROM devices dev
           INNER JOIN downloadtracks down
             ON dev.recid = down.deviceid
         GROUP BY dev.recid
         ORDER BY MAX(down.reccreated) DESC
         LIMIT 100;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getlastdevices()
  OWNER TO postgres;



-- Function: public.getlasttracks(uuid, integer)

-- DROP FUNCTION public.getlasttracks(uuid, integer);

CREATE OR REPLACE FUNCTION public.getlasttracks(
    IN i_deviceid uuid,
    IN i_count integer)
  RETURNS TABLE(recid uuid, reccreated timestamp without time zone, recname character varying, recupdated timestamp without time zone, deviceid uuid, trackid uuid, methodid integer, txtrecommendinfo character varying, userrecommend uuid) AS
$BODY$
BEGIN
  IF i_count < 0 THEN
    i_count = null;
  END IF;
RETURN QUERY SELECT *
  FROM downloadtracks
  WHERE downloadtracks.deviceid = i_deviceid
  ORDER BY downloadtracks.reccreated DESC
  LIMIT i_count;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getlasttracks(uuid, integer)
  OWNER TO postgres;



-- Function: public.getlastusers(integer)

-- DROP FUNCTION public.getlastusers(integer);

CREATE OR REPLACE FUNCTION public.getlastusers(IN i_count integer)
  RETURNS TABLE(usid character varying, regdate character varying, lastactive character varying, devicename character varying, recupdated character varying, owntracks bigint, downloadtracks bigint) AS
$BODY$
BEGIN
  IF i_count < 0 THEN
    i_count = null;
  END IF;
  RETURN QUERY SELECT
    CAST((res1.recid) AS CHARACTER VARYING),
    CAST((res1.reccreated) AS CHARACTER VARYING), 
    CAST((MAX(res2.reccreated)) AS CHARACTER VARYING), 
    res1.recname, 
    CAST((res1.recupdated) AS CHARACTER VARYING), 
    res1.owntracks, 
    COUNT(res2.userid) AS lasttracks
    FROM
    (SELECT u.recid, u.reccreated, u.recname, u.recupdated, COUNT(r.recid) AS owntracks
      FROM users u
      LEFT OUTER JOIN ratings r ON u.recid = r.userid
        AND r.ratingsum >= 0
      GROUP BY u.recid) res1
    LEFT OUTER JOIN (SELECT d.reccreated, dev.userid FROM downloadtracks d
          INNER JOIN devices dev
          ON dev.recid= d.deviceid
            --AND d.reccreated > localtimestamp - INTERVAL '1 day'
          ) res2
      ON res2.userid = res1.recid
    GROUP BY res1.recid, res1.reccreated, res1.recname, res1.recupdated, res1.owntracks
    ORDER BY MAX(res2.reccreated) DESC NULLS LAST 
    LIMIT i_count;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getlastusers(integer)
  OWNER TO postgres;


-- Function: public.getnexttrack_v2(uuid)

-- DROP FUNCTION public.getnexttrack_v2(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrack_v2(IN i_deviceid uuid)
  RETURNS TABLE(track character varying, method integer, useridrecommended character varying, txtrecommendedinfo character varying, timeexecute character varying) AS
$BODY$
DECLARE
    declare t timestamptz := clock_timestamp(); -- ���������� ��������� ����� ���������� ���������
    i_userid UUID = i_deviceid; -- � ���������� �������� ���������� userid �� deviceid
BEGIN
  -- ��������� ����������, ���� ��� ��� �� ����������
  PERFORM registerdevice(i_deviceid, 'New device');

  -- ���������� trackid, ����������� ��� � character varying, � methodid
  RETURN QUERY SELECT
           CAST((nexttrack.track) AS CHARACTER VARYING),
           nexttrack.methodid,
           CAST((nexttrack.useridrecommended) AS CHARACTER VARYING),
           nexttrack.txtrecommendedinfo,
           CAST((clock_timestamp() - t ) AS CHARACTER VARYING) -- ���������� ����� ���������� ���������
         FROM getnexttrackid_v17(i_deviceid) AS nexttrack;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrack_v2(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v10(uuid)

-- DROP FUNCTION public.getnexttrackid_v10(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v10(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying) AS
$BODY$
DECLARE
  i_userid   UUID = i_deviceid; --���� �� ����������� ����������� ������������� - ����� ����������
  rnd        INTEGER = (SELECT trunc(random() * 1001)); -- ���������� ��������� ����� ����� � ��������� �� 1 �� 1000
  o_methodid INTEGER; -- id ������ ������ �����
  owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
  arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
  exceptusers uuid ARRAY; -- ������ ������������� ��� i_userid � �������� �� ���� ����������� �� ������
BEGIN
  DROP TABLE IF EXISTS temp_track;
  CREATE TEMP TABLE temp_track(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying);

  -- �������� ��������� ����

  -- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
  owntracks = (SELECT COUNT(*)
         FROM (
              SELECT *
              FROM ratings
              WHERE userid = i_userid
                AND ratingsum >= 0
              LIMIT 900) AS count);

  -- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
  -- � ������������� ���������, �� ����������� ������������ �� ��������� �����

  IF (rnd < owntracks)
  THEN
    o_methodid = 2; -- ����� ������ �� ����� ������
    INSERT INTO temp_track (
    SELECT
      trackid,
      o_methodid,
      (SELECT CAST((null) AS UUID)),
      (SELECT CAST((null) AS CHARACTER VARYING))
    FROM ratings
    WHERE userid = i_userid
        AND lastlisten < localtimestamp - INTERVAL '1 day'
        AND ratingsum >= 0
        AND (SELECT isexist
           FROM tracks
           WHERE recid = trackid) = 1
        AND ((SELECT length
          FROM tracks
          WHERE recid = trackid) >= 120
           OR (SELECT length
             FROM tracks
             WHERE recid = trackid) IS NULL)
        AND ((SELECT iscensorial
          FROM tracks
          WHERE recid = trackid) IS NULL
           OR (SELECT iscensorial
             FROM tracks
             WHERE recid = trackid) != 0)
        AND trackid NOT IN (SELECT trackid
                  FROM downloadtracks
                  WHERE reccreated > localtimestamp - INTERVAL '1 day')
    ORDER BY RANDOM()
    LIMIT 1);

    -- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
    IF FOUND THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
      RETURN QUERY SELECT * FROM temp_track;
      RETURN;
    END IF;
  END IF;

  -- ���� rnd ������ ���������� "�����" ������ - ����������� ���� �� ������ ������������ � ����������
  -- ������������� �������� ��������� � ���������� ��������� �������������

  -- ������� ���� ������������� � ��������������� ������������� �������� ��������� ��� i_userid
  -- ������������ �� �������� �������������
  arrusers = (SELECT ARRAY (SELECT CASE WHEN userid1 = i_userid THEN userid2
                   WHEN userid2 = i_userid THEN userid1
                   ELSE NULL
                   END
                FROM ratios
                WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >= 0
                ORDER BY ratio DESC
  ));
  -- �������� ������������ i, � ������� � ���� ������������ �����������. ����� ��� ������ ���� ����
  -- � ������������ ��������� �������������, �� ����������� ��� ������������ ������������� i_userid.
  -- ���� ������������� ������ - ����� ���������� ������������ � ���������� ������������� �� ����������.
  FOR i IN 1.. (SELECT COUNT (*) FROM unnest(arrusers)) LOOP
    o_methodid = 4; -- ����� ������ �� ��������������� ������
    INSERT INTO temp_track (
      SELECT
      trackid,
      o_methodid,
      arrusers[i],
      (SELECT CAST ((concat('����������� �������� ', ratio)) AS CHARACTER VARYING)
       FROM ratios
       WHERE userid1 = i_userid AND userid2 = arrusers[i] OR userid2 = i_userid AND userid1 = arrusers[i]  LIMIT 1)
    FROM ratings
    WHERE userid = arrusers[i]
        AND ratingsum > 0
        AND trackid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
        AND trackid NOT IN (SELECT trackid
                  FROM downloadtracks
                  WHERE deviceid = i_deviceid
                    AND reccreated > localtimestamp - INTERVAL '1 day')
        AND (SELECT isexist
           FROM tracks
           WHERE recid = trackid) = 1
        AND ((SELECT length
          FROM tracks
          WHERE recid = trackid) >= 120
           OR (SELECT length
             FROM tracks
             WHERE recid = trackid) IS NULL)
        AND ((SELECT iscensorial
          FROM tracks
          WHERE recid = trackid) IS NULL
           OR (SELECT iscensorial
             FROM tracks
             WHERE recid = trackid) != 0)
    ORDER BY ratingsum DESC, RANDOM()
    LIMIT 1);
    -- ���� ����� ��� ������������� - ������� �� �������
    IF found THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
      RETURN QUERY SELECT * FROM temp_track;
      RETURN;
    END IF;
  END LOOP;
  -- ��� ���������� ������������, �������� ��������� ���� �� �������������� ������ � ���������������
  -- ��������� ����� ������������� � �������� �� ���� ����������� �� ������.
  exceptusers = (SELECT ARRAY (
    SELECT * FROM (
              SELECT recid FROM users WHERE recid != i_userid
              EXCEPT
              (SELECT CASE WHEN userid1 = i_userid THEN userid2
                  WHEN userid2 = i_userid THEN userid1
                  ELSE NULL
                  END
               FROM ratios WHERE userid1 = i_userid OR userid2 = i_userid)
            ) AS us
    ORDER BY RANDOM()
  )
  );
  FOR i IN 1.. (SELECT COUNT (*) FROM unnest(exceptusers)) LOOP
    o_methodid = 6; -- ����� ������ �� �������������� ������ � ��������������� ��������� ����� ������������� � �������� �� ���� �����������
    INSERT INTO temp_track (
    SELECT
      recid,
      o_methodid,
      exceptusers[i],
      (SELECT CAST(('������������� �� ������������ � ������� �� ���� �����������') AS CHARACTER VARYING))
    FROM tracks
    WHERE recid IN (SELECT trackid FROM ratings WHERE userid = exceptusers[i] AND ratingsum >= 0)
        AND recid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
        AND isexist = 1
        AND (iscensorial IS NULL OR iscensorial != 0)
        AND (length > 120 OR length IS NULL)
        AND recid NOT IN (SELECT trackid
                FROM downloadtracks
                WHERE reccreated > localtimestamp - INTERVAL '1 day')
    ORDER BY RANDOM()
    LIMIT 1);
    -- ���� ����� ��� ������������� - ������� �� �������
    IF found THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
      RETURN QUERY SELECT * FROM temp_track;
      RETURN;
    ELSE

    END IF;
  END LOOP;

  -- ���� ����� ������ ��� - �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
  o_methodid = 3; -- ����� ������ �� �������������� ������
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST((null) AS CHARACTER VARYING))
  FROM tracks
  WHERE recid NOT IN
      (SELECT trackid
       FROM ratings
       WHERE userid = i_userid)
      AND isexist = 1
      AND (iscensorial IS NULL OR iscensorial != 0)
      AND (length > 120 OR length IS NULL)
      AND recid NOT IN (SELECT trackid
              FROM downloadtracks
              WHERE reccreated > localtimestamp - INTERVAL '1 day')
  ORDER BY RANDOM()
  LIMIT 1);

  -- ���� ����� ���� ������ - ����� �� �������, ������� ���������� ��������
  IF FOUND THEN
    INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
    RETURN QUERY SELECT * FROM temp_track;
    RETURN;
  END IF;

  -- ���� ���������� ������� ������� null, �������� ��������� ����
  o_methodid = 1; -- ����� ������ ���������� �����
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST((null) AS CHARACTER VARYING))
  FROM tracks
  WHERE isexist = 1
      AND (iscensorial IS NULL OR iscensorial != 0)
      AND (length > 120 OR length IS NULL)
  ORDER BY RANDOM()
  LIMIT 1);
  INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
  RETURN QUERY SELECT * FROM temp_track;
  RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v10(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v15(uuid)

-- DROP FUNCTION public.getnexttrackid_v15(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v15(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying) AS
$BODY$

-- ������� ������ ������ ������������
DECLARE
  i_userid   UUID = i_deviceid; -- �� ������, ���� ���������� ��� �� ���������������� � ������������ �� ����������
  rnd        INTEGER = (SELECT trunc(random() * 1001)); -- ���������� ��������� ����� ����� � ��������� �� 1 �� 1000
  o_methodid INTEGER; -- id ������ ������ �����
  owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
  arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
  exceptusers uuid ARRAY; -- ������ ������������� ��� i_userid � �������� �� ���� ����������� �� ������
  temp_trackid uuid; 
  tmp_txtrecommendinfo text;
BEGIN
  -- temp_track - ��������� ������� ��� �������������� ���������� (������������ ����� ��������� ������ ������� ��������� � ������� downloadtracks, � ����� ����������
  DROP TABLE IF EXISTS temp_track; 
  CREATE TEMP TABLE temp_track(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying);

  --���� ���������� �� ���� ���������������� ����� - ������������ ���
  IF NOT EXISTS(SELECT recid
      FROM devices
      WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
  -- ���� ���������� ���������������� - ���� ���������������� ��� ������������
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;


  -- �������� ��������� ����

  -- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
  -- owntracks = (SELECT COUNT(*)
--         FROM (
--              SELECT *
--              FROM ratings
--              WHERE userid = i_userid
--                AND ratingsum >= 0
--              LIMIT 900) AS count);

  -- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
  -- � ������������� ���������, �� ����������� ������������ �� ��������� �����

--  IF (rnd < owntracks)
--  THEN
--    o_methodid = 2; -- ����� ������ �� ����� ������
--    INSERT INTO temp_track (
--    SELECT
--      trackid, -- �������� id �����
--      o_methodid,
--      (SELECT CAST((null) AS UUID)),
--      (SELECT CAST(('��������� ���� �� �����') AS CHARACTER VARYING))
--    FROM ratings -- �� ������, ������� ������� ��� ������� ������������
--    WHERE userid = i_userid
--        AND lastlisten < localtimestamp - INTERVAL '1 day' -- ��� �������� ��������� ������������� ���� �����, ��� �� ����� �� ������
--        AND ratingsum >= 0 -- ������� ����� ���������������
--        AND (SELECT isexist
--           FROM tracks
--           WHERE recid = trackid) = 1 -- ���� ���������� �� �������
--        AND ((SELECT length
--          FROM tracks
--          WHERE recid = trackid) >= 120 -- ����������������� ����� ������ ���� �����
--           OR (SELECT length
--             FROM tracks
--             WHERE recid = trackid) IS NULL) -- ��� ����� ����� �� ��������
--        AND ((SELECT iscensorial
--          FROM tracks
--          WHERE recid = trackid) IS NULL -- ���� ������ ���� ��������� ��� �������������
--           OR (SELECT iscensorial
--             FROM tracks
--             WHERE recid = trackid) != 0)
--        AND trackid NOT IN (SELECT trackid
--                  FROM downloadtracks
--                  WHERE reccreated > localtimestamp - INTERVAL '1 week' AND deviceid = i_deviceid) -- ���� �������� ���� ����� � ��������� ������
--    ORDER BY RANDOM()
--    LIMIT 1);

--    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
--    IF FOUND THEN
--      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
--      RETURN QUERY SELECT * FROM temp_track;
--      RETURN;
--    END IF;
--  END IF;

  -- ���� rnd ������ ���������� "�����" ������ - ���������� �������� �������������

  -- ���� ������������� ����������� �������� ��������� ������ ��� � ����� ��������������,
--  IF (SELECT COUNT (*) FROM ratios WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >=0) > 5 THEN
  -- ����������� ���� � ������������ ��������� ����� �������������, � �������� ���� �����������
    o_methodid = 7; -- ����� ������ �� ��������������� ������
    SELECT rn_trackid, rn_txtrecommendinfo INTO temp_trackid, tmp_txtrecommendinfo FROM getrecommendedtrackid_v5(i_userid);
    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
    IF temp_trackid IS NOT null THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),
              now(),
              null,
              null, 
              i_deviceid,
              temp_trackid,
              o_methodid,
              (SELECT CAST((
                tmp_txtrecommendinfo
                ) AS CHARACTER VARYING)),
              (SELECT CAST((null) AS UUID)) );
    RETURN QUERY 
      SELECT temp_trackid,
      o_methodid,
      (SELECT CAST((null) AS UUID)),
      (SELECT CAST((
        tmp_txtrecommendinfo
        ) AS CHARACTER VARYING));
    RETURN;
    END IF;
--  END IF;

  -- ���� ����� ������ ��� - �������� ��������� ���� �� �� ���� �� ������������ ������������� ������
  o_methodid = 3; -- ����� ������ �� �������������� ������
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('��������� ���� �� �������������� �������������') AS CHARACTER VARYING))
  FROM tracks
  WHERE recid NOT IN
      (SELECT trackid
       FROM ratings
       WHERE userid = i_userid)
      AND isexist = 1
      AND (iscensorial IS NULL OR iscensorial != 0)
      AND (length > 120 OR length IS NULL)
      AND recid NOT IN (SELECT trackid
              FROM downloadtracks
              WHERE reccreated > localtimestamp - INTERVAL '1 week'  AND deviceid = i_deviceid)
  ORDER BY RANDOM()
  LIMIT 1);

  -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
  IF FOUND THEN
    INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
    RETURN QUERY SELECT * FROM temp_track;
    RETURN;
  END IF;

  -- ���� ���������� ������� ������� null, �������� ��������� ����
  o_methodid = 1; -- ����� ������ ���������� �����
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('��������� ���� �� ����') AS CHARACTER VARYING))
  FROM tracks
  WHERE isexist = 1 -- ������������ �� ������� 
      AND (iscensorial IS NULL OR iscensorial != 0) -- ���������
      AND (length > 120 OR length IS NULL) -- ������������������ ����� 2� �����
  ORDER BY RANDOM()
  LIMIT 1);
  INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
  RETURN QUERY SELECT * FROM temp_track;
  RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v15(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v16(uuid)

-- DROP FUNCTION public.getnexttrackid_v16(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v16(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying) AS
$BODY$

-- ������� ������ ������ ������������
DECLARE
  i_userid   UUID = i_deviceid; -- �� ������, ���� ���������� ��� �� ���������������� � ������������ �� ����������
  rnd        INTEGER = (SELECT trunc(random() * 1001)); -- ���������� ��������� ����� ����� � ��������� �� 1 �� 1000
  o_methodid INTEGER; -- id ������ ������ �����
  owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
  arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
  exceptusers uuid ARRAY; -- ������ ������������� ��� i_userid � �������� �� ���� ����������� �� ������
  temp_trackid uuid; 
  tmp_txtrecommendinfo text;
BEGIN
  -- temp_track - ��������� ������� ��� �������������� ���������� (������������ ����� ��������� ������ ������� ��������� � ������� downloadtracks, � ����� ����������
  DROP TABLE IF EXISTS temp_track; 
  CREATE TEMP TABLE temp_track(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying);

  --���� ���������� �� ���� ���������������� ����� - ������������ ���
  IF NOT EXISTS(SELECT recid
      FROM devices
      WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
  -- ���� ���������� ���������������� - ���� ���������������� ��� ������������
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;


  -- �������� ��������� ����

  -- ���������� ���������� "�����" ������ ������������, ����������� ��� 900
  -- owntracks = (SELECT COUNT(*)
--         FROM (
--              SELECT *
--              FROM ratings
--              WHERE userid = i_userid
--                AND ratingsum >= 0
--              LIMIT 900) AS count);

  -- ���� rnd ������ ���������� "�����" ������, �������� ���� �� ������ ������������ (����������� �� ��� ������������ �� �����)
  -- � ������������� ���������, �� ����������� ������������ �� ��������� �����

--  IF (rnd < owntracks)
--  THEN
--    o_methodid = 2; -- ����� ������ �� ����� ������
--    INSERT INTO temp_track (
--    SELECT
--      trackid, -- �������� id �����
--      o_methodid,
--      (SELECT CAST((null) AS UUID)),
--      (SELECT CAST(('��������� ���� �� �����') AS CHARACTER VARYING))
--    FROM ratings -- �� ������, ������� ������� ��� ������� ������������
--    WHERE userid = i_userid
--        AND lastlisten < localtimestamp - INTERVAL '1 day' -- ��� �������� ��������� ������������� ���� �����, ��� �� ����� �� ������
--        AND ratingsum >= 0 -- ������� ����� ���������������
--        AND (SELECT isexist
--           FROM tracks
--           WHERE recid = trackid) = 1 -- ���� ���������� �� �������
--        AND ((SELECT length
--          FROM tracks
--          WHERE recid = trackid) >= 120 -- ����������������� ����� ������ ���� �����
--           OR (SELECT length
--             FROM tracks
--             WHERE recid = trackid) IS NULL) -- ��� ����� ����� �� ��������
--        AND ((SELECT iscensorial
--          FROM tracks
--          WHERE recid = trackid) IS NULL -- ���� ������ ���� ��������� ��� �������������
--           OR (SELECT iscensorial
--             FROM tracks
--             WHERE recid = trackid) != 0)
--        AND trackid NOT IN (SELECT trackid
--                  FROM downloadtracks
--                  WHERE reccreated > localtimestamp - INTERVAL '1 week' AND deviceid = i_deviceid) -- ���� �������� ���� ����� � ��������� ������
--    ORDER BY RANDOM()
--    LIMIT 1);

--    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
--    IF FOUND THEN
--      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
--      RETURN QUERY SELECT * FROM temp_track;
--      RETURN;
--    END IF;
--  END IF;

  -- ���� rnd ������ ���������� "�����" ������ - ���������� �������� �������������

  -- ���� ������������� ����������� �������� ��������� ������ ��� � ����� ��������������,
--  IF (SELECT COUNT (*) FROM ratios WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >=0) > 5 THEN
  -- ����������� ���� � ������������ ��������� ����� �������������, � �������� ���� �����������
    o_methodid = 7; -- ����� ������ �� ��������������� ������
    SELECT rn_trackid, rn_txtrecommendinfo INTO temp_trackid, tmp_txtrecommendinfo FROM getrecommendedtrackid_v6(i_userid);
    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
    IF temp_trackid IS NOT null THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),
              now(),
              null,
              null, 
              i_deviceid,
              temp_trackid,
              o_methodid,
              (SELECT CAST((
                tmp_txtrecommendinfo
                ) AS CHARACTER VARYING)),
              (SELECT CAST((null) AS UUID)) );
    RETURN QUERY 
      SELECT temp_trackid,
      o_methodid,
      (SELECT CAST((null) AS UUID)),
      (SELECT CAST((
        tmp_txtrecommendinfo
        ) AS CHARACTER VARYING));
    RETURN;
    END IF;
--  END IF;

  -- ���� ����� ������ ��� - �������� ���������� ���� �� �� ���� �� ������������ ������������� ������
  o_methodid = 3; -- ����� ������ ���������� �� �������������� ������
  INSERT INTO temp_track (
  SELECT
    trackid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('���������� ���� �� �������������� �������������') AS CHARACTER VARYING))
    FROM ratings
      WHERE userid IN (SELECT recid FROM users WHERE experience >= 10)
        AND userid != i_userid
        AND (SELECT recid FROM tracks 
            WHERE recid = trackid
              AND isexist = 1 -- ���� ���������� �� �������
              AND (length >= 120 OR length IS NULL) -- ����������������� ����� ������ ���� ����� ��� ����� ����� �� ��������
              AND (iscensorial != 0 OR iscensorial IS NULL)) IS NOT NULL --���� ������ ���� ��������� ��� �������������
        AND trackid NOT IN (SELECT trackid
              FROM downloadtracks
              WHERE deviceid = i_deviceid)


    GROUP BY trackid
    ORDER BY sum(ratingsum) DESC, RANDOM()
    LIMIT 1);

  -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
  IF FOUND THEN
    INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
    RETURN QUERY SELECT * FROM temp_track;
    RETURN;
  END IF;

  -- ���� ���������� ������� ������� null, �������� ��������� ����
  o_methodid = 1; -- ����� ������ ���������� �����
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('��������� ���� �� ����') AS CHARACTER VARYING))
  FROM tracks
  WHERE isexist = 1 -- ������������ �� ������� 
      AND (iscensorial IS NULL OR iscensorial != 0) -- ���������
      AND (length > 120 OR length IS NULL) -- ������������������ ����� 2� �����
  ORDER BY RANDOM()
  LIMIT 1);
  INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
  RETURN QUERY SELECT * FROM temp_track;
  RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v16(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v17(uuid)

-- DROP FUNCTION public.getnexttrackid_v17(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v17(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying) AS
$BODY$

-- ������� ������ ������ ������������
DECLARE
  i_userid   UUID = i_deviceid; -- �� ������, ���� ���������� ��� �� ���������������� � ������������ �� ����������
  rnd        INTEGER = (SELECT trunc(random() * 1001)); -- ���������� ��������� ����� ����� � ��������� �� 1 �� 1000
  o_methodid INTEGER; -- id ������ ������ �����
  owntracks  INTEGER; -- ���������� "�����" ������ ������������ (�������� �� 900 ��)
  arrusers uuid ARRAY; -- ������ ������������� ��� i_userid � ���������������� �������������� �������� ���������
  exceptusers uuid ARRAY; -- ������ ������������� ��� i_userid � �������� �� ���� ����������� �� ������
  temp_trackid uuid; 
  tmp_txtrecommendinfo text;
BEGIN

  -- temp_track - ��������� ������� ��� �������������� ���������� (������������ ����� ��������� ������ ������� ��������� � ������� downloadtracks, � ����� ����������
  DROP TABLE IF EXISTS temp_track; 
  CREATE TEMP TABLE temp_track(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying);-- 

-- IF i_deviceid = '6d164484-295e-43fa-a6ca-b42a5896ba68' THEN 
--  INSERT INTO downloadtracks (SELECT uuid_generate_v4(),
--              now(),
--              null,
--              null, 
--              i_deviceid,
--              (SELECT CAST(('11111111-1111-1111-1111-000000000000') AS UUID)) ,
--              o_methodid,
--              (SELECT CAST((
--                tmp_txtrecommendinfo
--                ) AS CHARACTER VARYING)),
--              (SELECT CAST((null) AS UUID)) );
--    RETURN QUERY 
--      SELECT (SELECT CAST(('11111111-1111-1111-1111-000000000000') AS UUID)),
--      1,
--      (SELECT CAST((null) AS UUID)),
--      (SELECT CAST((
--        tmp_txtrecommendinfo
--        ) AS CHARACTER VARYING));
--    RETURN;
-- END IF;

  --���� ���������� �� ���� ���������������� ����� - ������������ ���
  IF NOT EXISTS(SELECT recid
      FROM devices
      WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
  -- ���� ���������� ���������������� - ���� ���������������� ��� ������������
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;


  -- �������� ��������� ����

  -- ���������� ���������� "�����" ������ ������������
  owntracks = (SELECT COUNT(*)
        FROM ratings
          WHERE userid = i_userid
            AND ratingsum >= 0);

  -- ���� ���������� "�����" ������ = 0 - ��������� ��������� ����������������
  IF (owntracks = 0) THEN
    o_methodid = 8; -- ����� ������ �� ��������������� ������
    SELECT o_trackid, o_textinfo INTO temp_trackid, tmp_txtrecommendinfo FROM populartracksrecommend_v1(i_userid);
    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
    IF temp_trackid IS NOT null THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),
              now(),
              null,
              null, 
              i_deviceid,
              temp_trackid,
              o_methodid,
              (SELECT CAST((
                tmp_txtrecommendinfo
                ) AS CHARACTER VARYING)),
              (SELECT CAST((null) AS UUID)) );
    RETURN QUERY 
      SELECT temp_trackid,
      o_methodid,
      (SELECT CAST((null) AS UUID)),
      (SELECT CAST((
        tmp_txtrecommendinfo
        ) AS CHARACTER VARYING));
    RETURN;
    END IF;
  END IF;
--  IF (rnd < owntracks)
--  THEN
--    o_methodid = 2; -- ����� ������ �� ����� ������
--    INSERT INTO temp_track (
--    SELECT
--      trackid, -- �������� id �����
--      o_methodid,
--      (SELECT CAST((null) AS UUID)),
--      (SELECT CAST(('��������� ���� �� �����') AS CHARACTER VARYING))
--    FROM ratings -- �� ������, ������� ������� ��� ������� ������������
--    WHERE userid = i_userid
--        AND lastlisten < localtimestamp - INTERVAL '1 day' -- ��� �������� ��������� ������������� ���� �����, ��� �� ����� �� ������
--        AND ratingsum >= 0 -- ������� ����� ���������������
--        AND (SELECT isexist
--           FROM tracks
--           WHERE recid = trackid) = 1 -- ���� ���������� �� �������
--        AND ((SELECT length
--          FROM tracks
--          WHERE recid = trackid) >= 120 -- ����������������� ����� ������ ���� �����
--           OR (SELECT length
--             FROM tracks
--             WHERE recid = trackid) IS NULL) -- ��� ����� ����� �� ��������
--        AND ((SELECT iscensorial
--          FROM tracks
--          WHERE recid = trackid) IS NULL -- ���� ������ ���� ��������� ��� �������������
--           OR (SELECT iscensorial
--             FROM tracks
--             WHERE recid = trackid) != 0)
--        AND trackid NOT IN (SELECT trackid
--                  FROM downloadtracks
--                  WHERE reccreated > localtimestamp - INTERVAL '1 week' AND deviceid = i_deviceid) -- ���� �������� ���� ����� � ��������� ������
--    ORDER BY RANDOM()
--    LIMIT 1);

--    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
--    IF FOUND THEN
--      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
--      RETURN QUERY SELECT * FROM temp_track;
--      RETURN;
--    END IF;
--  END IF;

  -- ���� rnd ������ ���������� "�����" ������ - ���������� �������� �������������

  -- ���� ������������� ����������� �������� ��������� ������ ��� � ����� ��������������,
--  IF (SELECT COUNT (*) FROM ratios WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >=0) > 5 THEN
  -- ����������� ���� � ������������ ��������� ����� �������������, � �������� ���� �����������
    o_methodid = 7; -- ����� ������ �� ��������������� ������
    SELECT rn_trackid, rn_txtrecommendinfo INTO temp_trackid, tmp_txtrecommendinfo FROM getrecommendedtrackid_v5(i_userid);
    -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
    IF temp_trackid IS NOT null THEN
      INSERT INTO downloadtracks (SELECT uuid_generate_v4(),
              now(),
              null,
              null, 
              i_deviceid,
              temp_trackid,
              o_methodid,
              (SELECT CAST((
                tmp_txtrecommendinfo
                ) AS CHARACTER VARYING)),
              (SELECT CAST((null) AS UUID)) );
    RETURN QUERY 
      SELECT temp_trackid,
      o_methodid,
      (SELECT CAST((null) AS UUID)),
      (SELECT CAST((
        tmp_txtrecommendinfo
        ) AS CHARACTER VARYING));
    RETURN;
    END IF;
--  END IF;

  -- ���� ����� ������ ��� - �������� ���������� ���� �� �� ���� �� ������������ ������������� ������
  o_methodid = 3; -- ����� ������ ���������� �� �������������� ������
  INSERT INTO temp_track (
  SELECT
    trackid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('���������� ���� �� �������������� �������������') AS CHARACTER VARYING))
    FROM ratings
      WHERE userid IN (SELECT recid FROM users WHERE experience >= 10)
        AND userid != i_userid
        AND (SELECT recid FROM tracks 
            WHERE recid = trackid
              AND isexist = 1 -- ���� ���������� �� �������
              AND (iscorrect IS NULL OR iscorrect != 0)
              AND (length >= 120 OR length IS NULL) -- ����������������� ����� ������ ���� ����� ��� ����� ����� �� ��������
              AND (iscensorial != 0 OR iscensorial IS NULL)) IS NOT NULL --���� ������ ���� ��������� ��� �������������
        AND trackid NOT IN (SELECT trackid
              FROM downloadtracks
              WHERE deviceid = i_deviceid)


    GROUP BY trackid
    ORDER BY sum(ratingsum) DESC, RANDOM()
    LIMIT 1);

  -- ���� ����� ���� ������ - ������ ���������� � ��� � downloadtracks, ����� �� �������, ������� ���������� ��������
  IF FOUND THEN
    INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
    RETURN QUERY SELECT * FROM temp_track;
    RETURN;
  END IF;

  -- ���� ���������� ������� ������� null, �������� ��������� ����
  o_methodid = 1; -- ����� ������ ���������� �����
  INSERT INTO temp_track (
  SELECT
    recid,
    o_methodid,
    (SELECT CAST((null) AS UUID)),
    (SELECT CAST(('��������� ���� �� ����') AS CHARACTER VARYING))
  FROM tracks
  WHERE isexist = 1 -- ������������ �� ������� 
    AND (iscorrect IS NULL OR iscorrect != 0)
      AND (iscensorial IS NULL OR iscensorial != 0) -- ���������
      AND (length > 120 OR length IS NULL) -- ������������������ ����� 2� �����
  ORDER BY RANDOM()
  LIMIT 1);
  INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
  RETURN QUERY SELECT * FROM temp_track;
  RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v17(uuid)
  OWNER TO postgres;


-- Function: public.getnexttrackid_v18_test(uuid)

-- DROP FUNCTION public.getnexttrackid_v18_test(uuid);

CREATE OR REPLACE FUNCTION public.getnexttrackid_v18_test(IN i_deviceid uuid)
  RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying) AS
$BODY$
DECLARE
  i_userid   UUID = i_deviceid; --���� �� ����������� ����������� ������������� - ����� ����������
  ex_userid uuid;
  rate integer;

BEGIN

-- ������� ������������ (������ 1)
-- ��� ������������ ����������� �������� �������� �������� � hibernate
  SELECT r2.userid
     , SUM(r.ratingsum * r2.ratingsum) as s INTO ex_userid, rate
     FROM ratings r
       INNER JOIN ratings r2 ON r.trackid = r2.trackid
     AND r.userid != r2.userid
     AND (
         r.userid = i_userid
         AND r2.userid IN (SELECT recid FROM users WHERE experience >= 10)
         ) 

    GROUP BY  r2.userid
    ORDER BY s DESC
    LIMIT 1;
    
    RETURN QUERY
    SELECT
      trackid,
      1,
      ex_userid,
      CAST ((concat('����������� �������� ', rate)) AS CHARACTER VARYING)
    FROM ratings
    WHERE userid = ex_userid
        AND ratingsum > 0
        AND trackid NOT IN (SELECT trackid FROM ratings WHERE userid = i_userid)
        -- AND trackid NOT IN (SELECT trackid
--                  FROM downloadtracks
--                  WHERE deviceid = i_deviceid
--                    --AND reccreated > localtimestamp - INTERVAL '1 day'
--                    )
--        AND (SELECT isexist
--           FROM tracks
--           WHERE recid = trackid) = 1
--        AND ((SELECT length
--          FROM tracks
--          WHERE recid = trackid) >= 120
--           OR (SELECT length
--             FROM tracks
--             WHERE recid = trackid) IS NULL)
--        AND ((SELECT iscensorial
--          FROM tracks
--          WHERE recid = trackid) IS NULL
--           OR (SELECT iscensorial
--             FROM tracks
--             WHERE recid = trackid) != 0)
    ORDER BY ratingsum DESC--, RANDOM()
    LIMIT 1;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getnexttrackid_v18_test(uuid)
  OWNER TO postgres;


-- Function: public.getrecommendedtrackid_v2(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v2(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v2(IN in_userid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_sum_rate bigint) AS
$BODY$

--DECLARE
--preferenced_track uuid;

BEGIN
RETURN QUERY (
  -- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
  -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
  -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid, table2.sum_rate-- INTO preferenced_track
    --tracks.recid, table2.sum_rate, tracks.localdevicepathupload, tracks.path
        FROM tracks
        INNER JOIN (
          --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
          --������� �� ���
          SELECT trackid, SUM(track_rating) AS sum_rate
          FROM(
            --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
            --� ��������, ���������� �� �� �����������
            SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
            FROM ratings


              --------------------------------------------------
              ---------------����� INNER JOIN-------------------
              --------------------------------------------------

              INNER JOIN
              (
                --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                --� �������� � UUID'�� ���� ���������.
                --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                --�������� ������������
                SELECT COALESCE(associated_experts.ratio, 1) AS ratio, all_experts.userid AS expert_id
                FROM
                (
                  --������� ������������ ������� ������������ � ���-���� �� ���������
                  --� UUID'� ���� ���������
                  SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                  FROM ratios
                  WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience = 10)
                ) AS associated_experts
                RIGHT JOIN 
                (
                  --������� UUID'� ���� ���������
                  SELECT recid AS userid
                  FROM users
                  WHERE experience = 10
                ) AS all_experts
                ON associated_experts.userid = all_experts.userid
              ) AS experts_ratios
              ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
              AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
              




              
              --------------------------------------------------
              --------------������ INNER JOIN-------------------
              --------------------------------------------------
              
              -- INNER JOIN ratios
--              --�������� �������� ������ � ��� �������������, � ������� ���� �����������
--              --� �������� � ������� ratios (����������� ���������� ������), �������� �������
--              --� ����� �������
--              ON ((ratings.userid = ratios.userid2 AND ratios.userid1 = in_userid)
--                -- ����� � ������
--                OR (ratings.userid = ratios.userid1 AND ratios.userid2 = in_userid))

 --             AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
 --             AND ratios.ratio > 0 --������� �������� ������, ������ � ������������� � ������������� ������������� ���������� ������ � ��������




              
          ) AS TracksRatings
          GROUP BY trackid
          ORDER BY sum_rate DESC
        ) AS table2
        ON tracks.recid = table2.trackid
        AND tracks.isexist = 1 --���� ������ ������������ �� �������
        AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
        AND tracks.length >= 120
        --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� �������
        AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                     WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
        AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
        ORDER BY table2.sum_rate DESC
           --���������� �� ������� ������� ����� ��� �������, ����� �������� ����� ������ � ��������� table2.sum_rate,
           --� ����� ������� ���� ���������� ������� �������� � ������������������ ������ ������
           --,tracks.recid
           ,random()
        LIMIT 1);
  --RETURN preferenced_track;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v2(uuid)
  OWNER TO postgres;


-- Function: public.getrecommendedtrackid_v3(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v3(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v3(IN in_userid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_sum_rate bigint, rn_rnd_in_range double precision) AS
$BODY$
BEGIN

DROP TABLE IF EXISTS tracks_with_sum_rates;
CREATE TEMP TABLE tracks_with_sum_rates
AS
-- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
  -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
  -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid AS track_id, tracks_sum_rates.sum_rate AS track_sum_rate-- INTO preferenced_track
    --tracks.recid, tracks_sum_rates.sum_rate, tracks.localdevicepathupload, tracks.path
        FROM tracks
        INNER JOIN (
          --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
          --������� �� ���
          SELECT trackid, SUM(track_rating) AS sum_rate
          FROM(
            --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
            --� ��������, ���������� �� �� �����������
            SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
            FROM ratings
              INNER JOIN
              (
                --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                --� �������� � UUID'�� ���� ���������.
                --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                --�������� ������������
                SELECT COALESCE(associated_experts.ratio, 1) AS ratio, all_experts.userid AS expert_id
                FROM
                (
                  --������� ������������ ������� ������������ � ���-���� �� ���������
                  --� UUID'� ���� ���������
                  SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                  FROM ratios
                  WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience = 10)
                ) AS associated_experts
                RIGHT JOIN 
                (
                  --������� UUID'� ���� ���������
                  SELECT recid AS userid
                  FROM users
                  WHERE experience = 10
                ) AS all_experts
                ON associated_experts.userid = all_experts.userid
              ) AS experts_ratios
              ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
              AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
          ) AS tracks_ratings
          GROUP BY trackid
          ORDER BY sum_rate DESC
        ) AS tracks_sum_rates
        ON tracks.recid = tracks_sum_rates.trackid
        AND tracks.isexist = 1 --���� ������ ������������ �� �������
        AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
        AND tracks.length >= 120
        --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� �������
        AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                     WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
        AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
        ORDER BY tracks_sum_rates.sum_rate DESC;
           --���������� �� ������� ������� ����� ��� �������, ����� �������� ����� ������ � ��������� tracks_sum_rates.sum_rate,
           --� ����� ������� ���� ���������� ������� �������� � ������������������ ������ ������
           --,tracks.recid
           --,random()
        --LIMIT 1


RETURN QUERY
  WITH rnd_in_range_table AS (
  SELECT random() * (SELECT MAX(tracks_with_sum_rates.track_sum_rate) FROM tracks_with_sum_rates AS tracks_with_sum_rates) AS rnd_in_range
  )
  SELECT *
  FROM (
      SELECT tracks_with_sum_rates.track_id, tracks_with_sum_rates.track_sum_rate, rnd_in_range
      FROM tracks_with_sum_rates CROSS JOIN rnd_in_range_table
  ) T
  WHERE track_sum_rate >= rnd_in_range
  ORDER BY track_sum_rate
    ,random()
  LIMIT 1;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v3(uuid)
  OWNER TO postgres;

-- Function: public.getrecommendedtrackid_v4(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v4(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v4(IN in_userid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_txtrecommendinfo text) AS
$BODY$

BEGIN
RETURN QUERY (
  SELECT result_table.track_id, 'getrecommendedtrackid_v4; sum_rate:' || result_table.sum_track_rate::text || '; rnd:' || result_table.rnd::text || '; rnd_sum_rate:' || (result_table.sum_track_rate * result_table.rnd)::text
  FROM
  (
  -- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
  -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
  -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid AS track_id, random() AS rnd, table2.sum_rate AS sum_track_rate-- INTO preferenced_track
    --tracks.recid, table2.sum_rate, tracks.localdevicepathupload, tracks.path
        FROM tracks
        INNER JOIN (
          --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
          --������� �� ���
          SELECT trackid, SUM(track_rating) AS sum_rate
          FROM(
            --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
            --� ��������, ���������� �� �� �����������
            SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
            FROM ratings
            INNER JOIN
              (
                --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                --� �������� � UUID'�� ���� ���������.
                --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                --�������� ������������
                SELECT COALESCE(associated_experts.ratio, 1) AS ratio, all_experts.userid AS expert_id
                FROM
                (
                  --������� ������������ ������� ������������ � ���-���� �� ���������
                  --� UUID'� ���� ���������
                  SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                  FROM ratios
                  WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience = 10)
                ) AS associated_experts
                RIGHT JOIN 
                (
                  --������� UUID'� ���� ���������
                  SELECT recid AS userid
                  FROM users
                  WHERE experience = 10
                ) AS all_experts
                ON associated_experts.userid = all_experts.userid
              ) AS experts_ratios
              ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
              AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
          ) AS TracksRatings
          GROUP BY trackid
          ORDER BY sum_rate DESC
        ) AS table2
        ON tracks.recid = table2.trackid
        AND tracks.isexist = 1 --���� ������ ������������ �� �������
        AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
        AND tracks.length >= 120
        --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� �������
        AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                     WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
        AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
        ORDER BY table2.sum_rate DESC
           --���������� �� ������� ������� ����� ��� �������, ����� �������� ����� ������ � ��������� table2.sum_rate,
           --� ����� ������� ���� ���������� ������� �������� � ������������������ ������ ������
           --,tracks.recid
           --,random()
        --LIMIT 100
        ) AS result_table
        --ORDER BY rnd_sum_rate DESC
        ORDER BY result_table.sum_track_rate * result_table.rnd DESC
        LIMIT 1
        );
  --RETURN preferenced_track;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v4(uuid)
  OWNER TO postgres;

-- Function: public.getrecommendedtrackid_v5(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v5(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v5(IN in_userid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_txtrecommendinfo text) AS
$BODY$

DECLARE 
rnd DOUBLE PRECISION;
execution_start_time TIMESTAMP;
tracks_with_sum_rates_created_time TIMESTAMP;
rnd_generated_time TIMESTAMP;

tracks_with_sum_rates_creation_time_txt TEXT;
rnd_generation_time_txt TEXT;

BEGIN
  --����� ������ ���������� ���� �������
  SELECT timeofday()::timestamp INTO execution_start_time;

  DROP TABLE IF EXISTS tracks_with_sum_rates;
  CREATE TEMP TABLE tracks_with_sum_rates
  AS
  -- ��������� ������� tracks � �������� ���� ������������ �������� ����� �� �����������
    -- � ����������� ������������ ��� ����������� ������ �������������� ���������� � �����
    -- � ���������� ����� � ��� ������� �� �������� tracks
    SELECT tracks.recid AS track_id, tracks_sum_rates.sum_rate AS track_sum_rate-- INTO preferenced_track
    --tracks.recid, tracks_sum_rates.sum_rate, tracks.localdevicepathupload, tracks.path
          FROM tracks
          INNER JOIN (
            --���������� �� ����� � ������� ����� ������������ ��������� �� ����������� ���
            --������� �� ���
            SELECT trackid, SUM(track_rating) AS sum_rate
            FROM(
              --����������� ������� � ��������� ���� ������, ��������� ��������������, ������� ����� �����������
              --� ��������, ���������� �� �� �����������
              SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
              FROM ratings
                INNER JOIN
                (
                  --�������� ������� ������������� ���������� ������ ��������� ������������ � ����������
                  --� �������� � UUID'�� ���� ���������.
                  --���� � ��������� ������������ ��� ����������� � �����-���� ���������, �� ������ 1 �
                  --�������� ������������
                  SELECT COALESCE(associated_experts.ratio, 0.7) AS ratio, all_experts.userid AS expert_id
                  FROM
                  (
                    --������� ������������ ������� ������������ � ���-���� �� ���������
                    --� UUID'� ���� ���������
                    SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
                    FROM ratios
                    WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience >= 10)
                  ) AS associated_experts
                  RIGHT JOIN 
                  (
                    --������� UUID'� ���� ���������
                    SELECT recid AS userid
                    FROM users
                    WHERE experience >= 10
                  ) AS all_experts
                  ON associated_experts.userid = all_experts.userid
                ) AS experts_ratios
                ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
                AND ratings.userid <> in_userid --������� ��� ������ ������, ����� ������, ������ �������� �������������
                AND experts_ratios.ratio > 0 --������� �������� ������, ������ � ������������� � ������������� ������������� ���������� ������ � ��������
            ) AS tracks_ratings
            GROUP BY trackid
            ORDER BY sum_rate DESC
          ) AS tracks_sum_rates
          ON tracks.recid = tracks_sum_rates.trackid
          AND tracks.isexist = 1 --���� ������ ������������ �� �������
          AND (iscorrect IS NULL OR iscorrect <> 0) -- ���� �� ������ ���� �����
          AND tracks.iscensorial <> 0 --���� �� ������ ���� ������� ��� �����������
          AND tracks.length >= 120
          
          --���� �� ������ ��� ���������� ��������� ������������ � ������� ��������� ���� ������� (���� �������� �� ������� ����)
          --AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                 --WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
                 
          --���� �� ������ ��� ���������� ��������� ������������ ������ �������
          AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
                 WHERE deviceid = in_userid)
                 
          AND sum_rate >= 0 --� ����� ��������������� ����� ������ ����� � ������������� ������ ������������ ��������� �� ������������
          ORDER BY tracks_sum_rates.sum_rate DESC;


  --����� ����� �������� ������� tracks_with_sum_rates
  SELECT timeofday()::timestamp INTO tracks_with_sum_rates_created_time;
  
  --�� �������� ������� �������� execution_start_time � �������� � ������������� (numeric(18,3)), ����� ���������� � ��������� ���������� tracks_with_sum_rates_creation_time
  --����� ������� ���������� ����� �������� ��������� ������� tracks_with_sum_rates
  SELECT (cast(extract(epoch from (tracks_with_sum_rates_created_time - execution_start_time)) as numeric(18,3)))::text INTO tracks_with_sum_rates_creation_time_txt;
        
  --����������� ����� �� �������� � ������� ��������� ����� �� 0 �� 1 �� ����� ���� ���������
  --���������� ����� ������� � ���������� rnd
  --����� ��������� ����� ������ ���������� ����� ������� ����������� ������������ ����� �� �����-���� ������,
  --��� ����� ��������� ������ n � ��������� ������ n + 1 (������������� �� ����������� ��������) ����������
  --������� ����������� ������������ ����� �� ������ n + 1
  --������, �� ������� � ����� ��������������� ����, ����� ������������ ������ � ���������� rnd
  SELECT (random() * SUM(groups_by_rate.group_rate)) INTO rnd FROM
  ( --NULLIF ���������� NULL, ���� rate == 0, � COALESCE ���������� 0.3,
    --���� NULLIF ������ NULL, �������������� �������� ������ ����������
    --������� 0.3 ������ � ��������� 0
    SELECT COALESCE(NULLIF(track_sum_rate, 0), 0.3) AS group_rate FROM tracks_with_sum_rates
    GROUP BY track_sum_rate
    ORDER BY track_sum_rate
  ) AS groups_by_rate;

  --����� ����� ��������� rnd
  SELECT timeofday()::timestamp INTO rnd_generated_time;

  --�����, ����������� �� ��������� rnd
  SELECT (cast(extract(epoch from (rnd_generated_time - tracks_with_sum_rates_created_time)) as numeric(18,3)))::text INTO rnd_generation_time_txt;

  RETURN QUERY
  (
    --������� ��������� ���� �� ������, ���������� �� ��������� �������
    SELECT track_id, 'getrecommendedtrackid_v5; sum_rate:' || track_sum_rate::text || '; rnd_in_range:' || rnd::text || '; temp_table_creation:' || tracks_with_sum_rates_creation_time_txt || '; rnd_creation:' || rnd_generation_time_txt
    FROM tracks_with_sum_rates
    WHERE track_sum_rate = 
    (
      --���� ������� ���������� ������ �������� ����� 0.3, �� �������� �� 0
      --�.�. ������ � ��������� 0.3 �� ����������. �� ������������� �������� 0.3 ������ 0
      --����� ��� ��� �� ����� ��������� ���� ��������������� ��� �������������
      SELECT COALESCE(NULLIF(groups_by_rate_with_range_max.track_sum_rate, 0.3), 0)
      FROM
      (
          --������� ������ ������ ������ �� �����, ������������� �� ����������� ��������, ������� ������� �������� ������ ����� rnd
          SELECT SUM(groups_by_rate.group_rate) OVER (ORDER BY groups_by_rate.group_rate) AS group_range_max, groups_by_rate.group_rate AS track_sum_rate, rnd as rnd_in_range
          FROM
          (
        SELECT COALESCE(NULLIF(track_sum_rate, 0), 0.3) AS group_rate FROM tracks_with_sum_rates
        GROUP BY track_sum_rate
        ORDER BY track_sum_rate
          ) AS groups_by_rate
      ) AS groups_by_rate_with_range_max
      WHERE group_range_max >= rnd
      ORDER BY group_range_max
      LIMIT 1
    )
    ORDER BY random()
    LIMIT 1
  );  
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v5(uuid)
  OWNER TO postgres;

-- Function: public.getrecommendedtrackid_v5_debug(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v5_debug(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v5_debug(IN in_uuid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_txtrecommendinfo text) AS
$BODY$

BEGIN

  DROP TABLE IF EXISTS test_results;
  CREATE TEMP TABLE test_results
  (
    r_track_id UUID,
    r_info TEXT
  );
  
  FOR i IN 1..100
  LOOP
  INSERT INTO test_results
    SELECT * FROM getrecommendedtrackid_v5(in_uuid);
  END LOOP;

  RETURN QUERY
    SELECT * FROM test_results;
  
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v5_debug(uuid)
  OWNER TO postgres;

-- Function: public.getrecommendedtrackid_v6(uuid)

-- DROP FUNCTION public.getrecommendedtrackid_v6(uuid);

CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v6(IN in_uuid uuid)
  RETURNS TABLE(rn_trackid uuid, rn_txtrecommendinfo text) AS
$BODY$

BEGIN

-- �������� ������������� ��� ������������ Z
-- ��� 1. ������� �� ����� 5 ������������� ��������� � ���������� ���-��� ����������� ������������� ������ � ������������� Z
-- ��� 2. ������� �� ����� 1 ������������ �������� � ���������� ���-��� ����������� ��������� ������ � ������������� Z
-- ��� 3. ������� ����� ������ 6 ��������� 10 ������ ������������ ���������� ���-��� ������������� ����� ������ 6-�� ���������
-- ��� 4. ������� ��������� ���� ����� ������������ 10


  RETURN QUERY 
    (SELECT trackid, 'getrecommendedtrackid_v6; count_listen:' || tracks.count::text -- ��� 4
      FROM (SELECT trackid, count(*) as count -- ��� 3
        FROM histories
          WHERE (deviceid IN 
            (SELECT deviceid FROM ( -- ��� 1
              SELECT deviceid, count(*) as countListen 
                 FROM histories 
                 WHERE  islisten = 1 AND deviceid != in_uuid AND deviceid in (SELECT recid FROM users WHERE experience >= 10) 
                  AND trackid in (SELECT trackid FROM histories WHERE deviceid = in_uuid AND islisten = 1)  
                 GROUP BY deviceid
                 ORDER BY countListen DESC
                 LIMIT 5) as res1)
            
            OR deviceid IN ( 
              SELECT deviceid FROM ( -- ��� 2
                SELECT deviceid, count(*) as countListen 
                   FROM histories 
                   WHERE  islisten = -1 AND deviceid != in_uuid AND deviceid in (SELECT recid FROM users WHERE experience >= 10) 
                    AND trackid in (SELECT trackid FROM histories WHERE deviceid = in_uuid AND islisten = -1)  
                   GROUP BY deviceid
                   ORDER BY countListen DESC
                   LIMIT 1) as res2
                   )
            )
            AND trackid NOT IN (SELECT trackid FROM histories WHERE deviceid = in_uuid)
            AND trackid NOT IN (SELECT trackid FROM downloadtracks WHERE deviceid = in_uuid)
            
        GROUP BY trackid
        ORDER BY count DESC
        LIMIT 10) AS tracks
      ORDER BY random()
      LIMIT 1);
  
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getrecommendedtrackid_v6(uuid)
  OWNER TO postgres;

-- Function: public.gettrackshistorybydevice(uuid, integer)

-- DROP FUNCTION public.gettrackshistorybydevice(uuid, integer);

CREATE OR REPLACE FUNCTION public.gettrackshistorybydevice(
    IN i_deviceid uuid,
    IN i_count integer)
  RETURNS TABLE(downloadtrackrecid character varying, historyrecid character varying) AS
$BODY$
BEGIN
  IF i_count < 0 THEN
    i_count = null;
  END IF;
  RETURN QUERY SELECT CAST((d.recid) AS CHARACTER VARYING), CAST((h.recid) AS CHARACTER VARYING)
         FROM downloadtracks d
           LEFT OUTER JOIN histories h
             ON h.deviceid = d.deviceid AND h.trackid = d.trackid
         WHERE d.deviceid = i_deviceid
         ORDER BY d.reccreated DESC, h.reccreated DESC, h.lastlisten DESC
         LIMIT i_count;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.gettrackshistorybydevice(uuid, integer)
  OWNER TO postgres;


-- Function: public.gettracksratingbydevice(uuid, integer)

-- DROP FUNCTION public.gettracksratingbydevice(uuid, integer);

CREATE OR REPLACE FUNCTION public.gettracksratingbydevice(
    IN i_deviceid uuid,
    IN i_count integer)
  RETURNS TABLE(downloadtrackrecid character varying, ratingsrecid character varying) AS
$BODY$

-- ���������� id ������� � ����������� ������ � ������� �� ��� ����������
BEGIN
  IF i_count < 0 THEN
    i_count = null;
  END IF;
  RETURN QUERY SELECT CAST((d.recid) AS CHARACTER VARYING), CAST((r.recid) AS CHARACTER VARYING)
         FROM downloadtracks d
           LEFT OUTER JOIN ratings r
             ON r.userid = (SELECT userid FROM devices WHERE recid = d.deviceid) AND r.trackid = d.trackid
         WHERE d.deviceid = i_deviceid
         ORDER BY d.reccreated DESC, r.reccreated DESC, r.lastlisten DESC
         LIMIT i_count;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.gettracksratingbydevice(uuid, integer)
  OWNER TO postgres;

-- Function: public.getuploadersrating()

-- DROP FUNCTION public.getuploadersrating();

CREATE OR REPLACE FUNCTION public.getuploadersrating()
  RETURNS TABLE(userid character varying, uploadtracks bigint, lastactive character varying) AS
$BODY$

BEGIN
  --������� ���������� ������� uploader'��
  RETURN QUERY SELECT CAST((u.recid) AS CHARACTER VARYING), COUNT(t.recid), CAST((MAX(t.reccreated)) AS CHARACTER VARYING)
  FROM users u
    INNER JOIN tracks t
      ON u.recid = t.deviceid
  GROUP BY u.recid
  ORDER BY MAX(t.reccreated) DESC;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getuploadersrating()
  OWNER TO postgres;

-- Function: public.getuserdevices(uuid)

-- DROP FUNCTION public.getuserdevices(uuid);

CREATE OR REPLACE FUNCTION public.getuserdevices(IN i_userid uuid)
  RETURNS TABLE(recid uuid, reccreated timestamp without time zone, recname character varying, recupdated timestamp without time zone, userid uuid) AS
$BODY$
BEGIN
  RETURN QUERY
  SELECT * FROM devices WHERE devices.userid = i_userid;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getuserdevices(uuid)
  OWNER TO postgres;

-- Function: public.getusersrating(integer)

-- DROP FUNCTION public.getusersrating(integer);

CREATE OR REPLACE FUNCTION public.getusersrating(IN i_count integer)
  RETURNS TABLE(tuserid character varying, treccreated character varying, trecname character varying, trecupdated character varying, towntracks bigint, tlasttracks bigint) AS
$BODY$

BEGIN
  IF i_count < 0 THEN
    i_count = null;
  END IF;
RETURN QUERY SELECT CAST((res1.recid) AS CHARACTER VARYING), CAST((res1.reccreated) AS CHARACTER VARYING), res1.recname, CAST((res1.recupdated) AS CHARACTER VARYING), res1.owntracks, COUNT(res2.userid) AS lasttracks
FROM
  (SELECT u.recid, u.reccreated, u.recname, u.recupdated, COUNT(r.recid) AS owntracks
    FROM users u
    LEFT OUTER JOIN ratings r ON u.recid = r.userid
    GROUP BY u.recid) res1
  LEFT OUTER JOIN (SELECT d.reccreated, dev.userid FROM downloadtracks d
        INNER JOIN devices dev
        ON dev.recid= d.deviceid AND d.reccreated > localtimestamp - INTERVAL '1 day') res2
    ON res2.userid = res1.recid
  GROUP BY res1.recid, res1.reccreated, res1.recname, res1.recupdated, res1.owntracks
  ORDER BY lasttracks DESC, owntracks DESC
  LIMIT i_count;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getusersrating(integer)
  OWNER TO postgres;

-- Function: public.getuserstracks(uuid)

-- DROP FUNCTION public.getuserstracks(uuid);

CREATE OR REPLACE FUNCTION public.getuserstracks(IN i_userid uuid)
  RETURNS TABLE(tuserid character varying, listentracks bigint, downloadtracks bigint) AS
$BODY$

BEGIN
  RETURN QUERY SELECT CAST((res1.userid) AS CHARACTER VARYING), res1.owntracks, COUNT(res2.userid)
    FROM (SELECT userid, COUNT(recid) AS owntracks -- ������� ��� ������������ ������������� �����
      FROM ratings
      WHERE userid = i_userid
      GROUP BY userid) res1
    LEFT OUTER JOIN (SELECT dev.userid FROM downloadtracks d -- �������� ��� �������� ������������ �����
          INNER JOIN devices dev
          ON dev.recid = d.deviceid 
        ) res2
      ON res2.userid = res1.userid
    GROUP BY res1.userid, res1.owntracks;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.getuserstracks(uuid)
  OWNER TO postgres;


-- Function: public.populartracksrecommend_v1(uuid)

-- DROP FUNCTION public.populartracksrecommend_v1(uuid);

CREATE OR REPLACE FUNCTION public.populartracksrecommend_v1(
    IN i_userid uuid,
    OUT o_trackid uuid,
    OUT o_textinfo character varying)
  RETURNS record AS
$BODY$

-- ������� ������ ������ ������������, �� �������� ������������� �� ������ ������
BEGIN

  WITH exclude_users AS (
    SELECT r.userid 
      FROM downloadtracks d
        INNER JOIN ratings r
          ON d.trackid = r.trackid
      WHERE d.deviceid = i_userid
        AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)
      GROUP BY r.userid)
  SELECT recid, '����������������, ��������� ������� ����� ' || rate INTO o_trackid, o_textinfo 
    FROM (
    SELECT t.recid, SUM(r.ratingsum) AS rate
      FROM tracks t
        INNER JOIN ratings r
          ON t.recid = r.trackid    
            AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)
      WHERE t.recid NOT IN (SELECT trackid FROM ratings WHERE userid IN (SELECT * FROM exclude_users) GROUP BY trackid)
        AND isexist = 1
        AND (iscorrect IS NULL OR iscorrect <> 0)
        AND (iscensorial IS NULL OR iscensorial != 0)
        AND (length > 120 OR length IS NULL)
      GROUP BY t.recid
      ORDER BY rate DESC) AS res
    WHERE rate > 0
    LIMIT 1;
END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.populartracksrecommend_v1(uuid)
  OWNER TO postgres;


-- Function: public.registerdevice(uuid, character varying)

-- DROP FUNCTION public.registerdevice(uuid, character varying);

CREATE OR REPLACE FUNCTION public.registerdevice(
    i_deviceid uuid,
    i_devicename character varying)
  RETURNS boolean AS
$BODY$
BEGIN
  -- ������� ����������� ������ ����������

  -- ��������� ����������, ���� ��� ��� �� ����������
  -- ���� ID ���������� ��� ��� � ��
  IF NOT EXISTS(SELECT recid
          FROM devices
          WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_deviceid,
               i_devicename,
               now()
             WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_deviceid)
    ON CONFLICT (recid) DO NOTHING;

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
             i_deviceid,
             i_deviceid,
             i_devicename,
             now()
    ON CONFLICT (recid) DO NOTHING;
  END IF;
  RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.registerdevice(uuid, character varying)
  OWNER TO postgres;

-- Function: public.registertrack_v2(uuid, character varying, character varying, uuid, character varying, character varying, integer, integer)

-- DROP FUNCTION public.registertrack_v2(uuid, character varying, character varying, uuid, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.registertrack_v2(
    i_trackid uuid,
    i_localdevicepathupload character varying,
    i_path character varying,
    i_deviceid uuid,
    i_title character varying,
    i_artist character varying,
    i_length integer,
    i_size integer)
  RETURNS boolean AS
$BODY$
DECLARE
  i_userid    UUID = i_deviceid;
  i_historyid UUID;
  i_ratingid  UUID;
BEGIN
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  SELECT uuid_generate_v4()
  INTO i_historyid;
  SELECT uuid_generate_v4()
  INTO i_ratingid;

  --
  -- ������� ��������� ������ � ����� � ������� ������ � ������ ������������� ������ �
  -- ������� ���������� ������������� � ���������. ���� ������������, ������������ ����
  -- ��� � ����, �� �� ����������� � ������� �������������.
  --

  -- ��������� ����������, ���� ��� ��� �� ����������
  -- ���� ID ���������� ��� ��� � ��
  IF NOT EXISTS(SELECT recid
          FROM devices
          WHERE recid = i_deviceid)
  THEN

    -- ��������� ������ ������������
    INSERT INTO users (recid, recname, reccreated) SELECT
               i_userid,
               'New user recname',
               now()
    WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

    -- ��������� ����� ����������
    INSERT INTO devices (recid, userid, recname, reccreated) SELECT
               i_deviceid,
               i_userid,
               'New device recname',
               now();
  ELSE
    SELECT (SELECT userid
        FROM devices
        WHERE recid = i_deviceid
        LIMIT 1)
    INTO i_userid;
  END IF;

  -- ��������� ���� � ���� ������
  INSERT INTO tracks (recid, localdevicepathupload, path, deviceid, reccreated, iscensorial, isexist, recname, artist, length, size)
  VALUES (i_trackid, i_localdevicepathupload, i_path, i_deviceid, now(), 2, 1, i_title, i_artist, i_length, i_size);

  -- ��������� ������ � ������������� ����� � ������� ������� �������������
  INSERT INTO histories (recid, deviceid, trackid, isListen, lastListen, reccreated)
  VALUES (i_historyid, i_deviceid, i_trackid, 1, now(), now());

  -- ��������� ������ � ������� ���������
  INSERT INTO ratings (recid, userid, trackid, lastListen, ratingsum, reccreated)
  VALUES (i_ratingid, i_userid, i_trackid, now(), 1, now());

  RETURN TRUE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.registertrack_v2(uuid, character varying, character varying, uuid, character varying, character varying, integer, integer)
  OWNER TO postgres;
