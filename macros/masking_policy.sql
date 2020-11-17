
{% macro masking_policy(masking_variables, roles_1=('',''), roles_2=('','') ) %}

    {# /* Creates temporary snapshot of the currently active masking policies in our schema */ #}

    {% set sql %}

        CREATE TEMPORARY TABLE SNAPSHOT_MASKING_POLICIES (
        SNAPSHOT_DATE TIMESTAMP,
        CREATED_ON TIMESTAMP,
        POLICY_NAME VARCHAR,
        POLICY_DB VARCHAR,
        POLICY_SCHEMA VARCHAR,
        POLICY_KIND VARCHAR,
        OWNER VARCHAR,
        COMMENT VARCHAR);

        SHOW MASKING POLICIES;
        insert into SNAPSHOT_MASKING_POLICIES (SNAPSHOT_DATE,CREATED_ON,POLICY_NAME,POLICY_DB,POLICY_SCHEMA,POLICY_KIND,OWNER,COMMENT)
        SELECT CURRENT_TIMESTAMP() AS SNAPSHOT_DATE, * 
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

        CREATE TEMPORARY TABLE SNAPSHOT_MASKING_POLICY_REFERENCES (
        SNAPSHOT_DATE TIMESTAMP,
        CREATED_ON TIMESTAMP,
        POLICY_DB VARCHAR,
        POLICY_SCHEMA VARCHAR,
        POLICY_NAME VARCHAR,
        POLICY_KIND VARCHAR,
        REF_DATABASE_NAME VARCHAR,
        REF_SCHEMA_NAME VARCHAR,
        REF_ENTITY_NAME VARCHAR,
        REF_ENTITY_DOMAIN VARCHAR,
        REF_COLUMN_NAME VARCHAR
        );

        CREATE OR REPLACE PROCEDURE UDP_GET_MASKING_POLICY_REFERENCES()
        RETURNS STRING  
        LANGUAGE JAVASCRIPT
        EXECUTE AS CALLER
        AS
        $$
            var return_val = "";
            var sql_command = "TRUNCATE TABLE SNAPSHOT_MASKING_POLICY_REFERENCES"; 
            try {
                var result_set = snowflake.execute ({sqlText: sql_command});
                }
            catch (err)  {
                return "Failed: "+ sql_command + ": " + err;   // Return a success/error indicator.
                }
            var sql_command = "select POLICY_DB||'.'||POLICY_SCHEMA||'.'||POLICY_NAME FROM SNAPSHOT_MASKING_POLICIES"; 
            try {
                var result_set = snowflake.execute ({sqlText: sql_command});
                while (result_set.next())  {
                v_policy_name = result_set.getColumnValue(1);
                if (return_val == "") {
                    return_val = v_policy_name;
                } else {
                    return_val = return_val + ", " + v_policy_name;
                }
                var sql_command2 = "INSERT INTO SNAPSHOT_MASKING_POLICY_REFERENCES SELECT CURRENT_TIMESTAMP() AS SNAPSHOT_DATE, * FROM table(information_schema.policy_references(policy_name => '" + v_policy_name + "'))"
                var create_insert_stmt = snowflake.createStatement({ sqlText: sql_command2 });
                try {
                    var result_set2 = create_insert_stmt.execute ();
                    }
                catch (err) {
                return "Failed: "+ sql_command2 + ": " + err;   // Return a success/error indicator.
                    }
                }
                return "Complete: " + return_val;   // Return a success/error indicator.
                }
            catch (err)  {
                return "Failed: "+ sql_command + ": " + err;   // Return a success/error indicator.
                }
        $$;

        CALL UDP_GET_MASKING_POLICY_REFERENCES();

    {% endset %}
    {% set table = run_query(sql) %}

    
    {# /* Calls the active masking from the previously created table and sets them to a variable */ #}

    {% call statement('load_set_policies', fetch_result=True) %}
        select REF_ENTITY_NAME, REF_COLUMN_NAME from SNAPSHOT_MASKING_POLICY_REFERENCES;
    {% endcall %}

    {% set set_policies = load_result('load_set_policies')['data'] %}

    {{ log("policy_result: " ~ set_policies, True) }}

    
    {# /* Loops over the set masking policies to unset them */ #}

    {% for policy_info in set_policies %}
        {{ log("mask_policy_table: " ~ set_policies[0], True) }}
        {{ log("mask_policy_column: " ~ set_policies[1], True) }}

        {% set sql %}
            alter table if exists {{ target.database }}.{{ target.schema }}.{{ policy_info[0] }} modify column {{ policy_info[1] }} unset masking policy;
        {% endset %}
        {% set table = run_query(sql) %}

    {% endfor %}


    {# /* Creates a masking policy per data type needed */ #}
    {# /* Salt is added to the md5 hash to prevent hacking */ #}

    {% set sql %}

        create or replace masking policy string_mask as (val string) returns string ->
            case
                when current_role() in ({% for role in roles_1 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %}) then val
                when val like '%@%.%'and current_role() in ({% for role in roles_2 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %}) then regexp_replace(val,'.+\@','*****@')
                when current_role() in ({% for role in roles_2 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %}) then (md5(val||'dl6K92s'))
                else '**********'
            end;
    
        create or replace masking policy date_mask as (val date) returns date ->
            case
                when current_role() in ({% for role in roles_1 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %})  then val
                when current_role() in ({% for role in roles_2 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %})  then NULL
                else NULL
            end;

        create or replace masking policy number_mask as (val number) returns number ->
            case
                when current_role() in ({% for role in roles_1 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %}) then val
                when current_role() in ({% for role in roles_2 %} '{{role}}' {%- if not loop.last %},{% endif -%}{% endfor %})  then NULL
                else NULL
            end;

    {% endset %}
    {% set table = run_query(sql) %}


    {# /* Sets the masking policy per data type and per column */ #}

    {% for masking_variable in masking_variables %}
    {{ log("column_name_set: " ~ masking_variable, True) }}

        {% call statement('load_data_type', fetch_result=True) %}

            select DATA_TYPE from {{ target.database }}."INFORMATION_SCHEMA"."COLUMNS" 
            where column_name = '{{ masking_variable[1] }}'
            and table_name = '{{ masking_variable[0] }}';

        {% endcall %}

        {% set data_type = load_result('load_data_type')['data'] %}
        {{ log("data_type: " ~ data_type, True) }}

        {% if data_type == [('DATE',)] %}
            {% set sql %}
                alter table if exists {{ target.database }}.{{ target.schema }}.{{ masking_variable[0] }} modify column {{ masking_variable[1] }} set masking policy date_mask;
            {% endset %}
        {% elif data_type == [('NUMBER',)] %}
            {% set sql %}
                alter table if exists {{ target.database }}.{{ target.schema }}.{{ masking_variable[0] }} modify column {{ masking_variable[1] }} set masking policy number_mask;
            {% endset %}
        {% else %}
            {% set sql %}
                alter table if exists {{ target.database }}.{{ target.schema }}.{{ masking_variable[0] }} modify column {{ masking_variable[1] }} set masking policy string_mask;
            {% endset %}
        {% endif %}
        {% set table = run_query(sql) %}

    {% endfor %}

{% endmacro %}