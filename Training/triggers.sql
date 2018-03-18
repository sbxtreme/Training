-- function to get columns of a table

CREATE OR REPLACE FUNCTION get_tab_cols (
    table_owner   VARCHAR2,
    t_name        VARCHAR2
) RETURN CLOB IS
    v_SQL   CLOB;
BEGIN
    FOR x IN (
        SELECT
            column_name
        FROM
            all_tab_columns
        WHERE
            table_name = t_name
            AND   owner = table_owner
            AND   data_type <> 'BLOB'
    ) LOOP
        v_SQL := v_SQL
        || ','
        || X.column_name
        || chr(10)
        || '';
    END LOOP;

    RETURN ltrim(v_SQL,',');
END;
/


-- comparison function

create or replace function column_comp (
     table_owner   VARCHAR2,
     t_name   VARCHAR2
  ) RETURN CLOB
  IS
    v_sql CLOB;
  BEGIN
    FOR recs IN (SELECT column_name
                     FROM all_tab_columns
                    WHERE table_name = t_name
                      AND owner = table_owner
                      AND data_type<>'BLOB')
   LOOP
      v_sql := v_sql
         || ' or( (:old.'
         || recs.column_name
         || ' <> :new.'
         || recs.column_name
         || ') or (:old.'
         || recs.column_name
         || ' IS NULL and  :new.'
         || recs.column_name
         || ' IS NOT NULL)  or (:old.'
         || recs.column_name
         || ' IS NOT NULL and  :new.'
         || recs.column_name
         || ' IS NULL))'
         || CHR (10)
         || '                ';
   END LOOP;

   v_sql := LTRIM (v_sql, ' or');
   RETURN v_sql;
  END;
  /

  
-- trigger on table

CREATE OR REPLACE PROCEDURE create_audit_triggers (table_owner VARCHAR2,t_name VARCHAR2)
IS
   CURSOR c_tab_inc (
      table_owner VARCHAR2,
      t_name VARCHAR2)
   IS
      SELECT ot.owner AS owner, ot.table_name AS table_name
        FROM all_tables ot
       WHERE     ot.owner = table_owner and ot.table_name=t_name;

   v_query   VARCHAR2 (32767);
   v_count   NUMBER := 0;
BEGIN
   FOR r_tab_inc IN c_tab_inc (table_owner,t_name)
   LOOP
      BEGIN

         v_query :=
               'CREATE OR REPLACE TRIGGER TRIGGER_'
            || r_tab_inc.table_name
            || ' AFTER INSERT OR UPDATE OR DELETE ON '
            || r_tab_inc.owner
            || '.'
            || r_tab_inc.table_name
            || ' FOR EACH ROW'
            || CHR (10)
            || 'DECLARE '
            || CHR (10)
            || ' v_user varchar2(30):=null;'
            || CHR (10)
            || ' v_action varchar2(15);'
            || CHR (10)
            || 'BEGIN'
            || CHR (10)
            || '   SELECT SYS_CONTEXT (''USERENV'', ''session_user'') session_user'
            || CHR (10)
            || '   INTO v_user'
            || CHR (10)
            || '   FROM DUAL;'
            || CHR (10)
            || ' if inserting then '
            || CHR (10)
            || ' v_action:=''INSERT'';'
            || CHR (10)
            || '      insert into AUDIT_'
            || r_tab_inc.table_name
            || '('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      NULL)
            || '      ,AUDIT_ACTION,AUDIT_BY,AUDIT_AT)'
            || CHR (10)
            || '      values ('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      ':new.')
            || '      ,''I'',v_user,SYSDATE);'
            || CHR (10)
            || ' elsif updating then '
            || CHR (10)
            || ' v_action:=''UPDATE'';'
            || CHR (10)
            || '   if '
            || column_comp (r_tab_inc.owner, r_tab_inc.table_name)
            || ' then '
            || CHR (10)
            || '      insert into AUDIT_'
            || r_tab_inc.table_name
            || '('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      NULL)
            || '      ,AUDIT_ACTION,AUDIT_BY,AUDIT_AT)'
            || CHR (10)
            || '      values ('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      ':new.')
            || '      ,''U'',v_user,SYSDATE);'
            || CHR (10)
            || '   end if;'
            || ' elsif deleting then'
            || CHR (10)
            || ' v_action:=''DELETING'';'
            || CHR (10)
            || '      insert into AUDIT_'
            || r_tab_inc.table_name
            || '('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      NULL)
            || '      ,AUDIT_ACTION,AUDIT_BY,AUDIT_AT)'
            || CHR (10)
            || '      values ('
            || get_tab_cols (r_tab_inc.owner,
                                      r_tab_inc.table_name,
                                      ':old.')
            || '      ,''D'',v_user,SYSDATE);'
            || CHR (10)
            || '   end if;'
            || CHR (10)
            || 'END;';

         DBMS_OUTPUT.put_line (
               'CREATE TRIGGER '
            || REPLACE (r_tab_inc.table_name, 'TABLE_', 'TRIGGER_'));

         EXECUTE IMMEDIATE v_query;

         DBMS_OUTPUT.put_line (
               'Audit trigger '
            || REPLACE (r_tab_inc.table_name, 'TABLE_', 'TRIGGER_')
            || ' created.');

         v_count := c_tab_inc%ROWCOUNT;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (
                  'Failed to create audit trigger for '
               || r_tab_inc.owner
               || '.'
               || r_tab_inc.table_name
               || ' due to '
               || SQLERRM);
      END;
   END LOOP;

   IF v_count = 0
   THEN
      DBMS_OUTPUT.put_line ('No audit triggers created');
   END IF;
END;
/