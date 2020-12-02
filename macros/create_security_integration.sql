
{% macro create_security_integration(new_integration_name) %}

    {# /* Call the current user from Snowflake (can't use the target file because this doesn't always correspond) */ #}

    {% call statement('current_user', fetch_result=True) %}
        SELECT CURRENT_USER();
    {% endcall %}

    {% set current_user = load_result('current_user')['data'] %}
    {{ log("Current user: " ~ current_user, True) }}

    {# /* Creates a temporary snapshot of roles granted to the current user to see whether the user can use the role 
          accountadmin */ #}

    {% for user in current_user %}
        {% set sql %}

            CREATE OR REPLACE TEMPORARY TABLE SNAPSHOT_GRANTS_USER (
            SNAPSHOT_DATE TIMESTAMP,
            CREATED_ON TIMESTAMP,
            GRANTS_ROLE VARCHAR,
            GRANTS_GRANTED_TO VARCHAR,
            GRANTS_GRANTEE_NAME VARCHAR,
            GRANTS_GRANTED_BY VARCHAR);

            show grants to user {{ user[0] }};
            INSERT INTO SNAPSHOT_GRANTS_USER (SNAPSHOT_DATE,CREATED_ON,GRANTS_ROLE,GRANTS_GRANTED_TO,GRANTS_GRANTEE_NAME,GRANTS_GRANTED_BY)
            SELECT CURRENT_TIMESTAMP() AS SNAPSHOT_DATE, * 
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

        {% endset %}
        {% set table = run_query(sql) %}
    {% endfor %}

    {% call statement('grants_user', fetch_result=True) %}
        SELECT GRANTS_ROLE from SNAPSHOT_GRANTS_USER where GRANTS_ROLE='ACCOUNTADMIN';
    {% endcall %}

    {% set grants_user = load_result('grants_user')['data'] %}
    {{ log("Grants to current user: " ~ grants_user, True) }}

    {# /* If loop to check whether the user can use the role accountadmin. */ #}

    {% if (grants_user|length) %}

        {# /* Creates a temporary snapshot of the active integrations to see whether the tableau_server security integration 
            already exists */ #}

        {% set sql %}

            USE ROLE ACCOUNTADMIN;

            CREATE OR REPLACE TEMPORARY TABLE SNAPSHOT_INTEGRATIONS (
            SNAPSHOT_DATE TIMESTAMP,
            INTEGRATION_NAME VARCHAR,
            INTEGRATION_TYPE VARCHAR,
            INTEGRATION_CATEGORY VARCHAR,
            INTEGRATION_ENABLED VARCHAR,
            CREATED_ON TIMESTAMP);

            SHOW integrations;
            INSERT INTO SNAPSHOT_INTEGRATIONS (SNAPSHOT_DATE,INTEGRATION_NAME,INTEGRATION_TYPE,INTEGRATION_CATEGORY,INTEGRATION_ENABLED,CREATED_ON)
            SELECT CURRENT_TIMESTAMP() AS SNAPSHOT_DATE, * 
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
        
        {% endset %}
        {% set table = run_query(sql) %}

        {% call statement('integration_name', fetch_result=True) %}
            SELECT INTEGRATION_NAME FROM SNAPSHOT_INTEGRATIONS WHERE INTEGRATION_TYPE='OAUTH - TABLEAU_SERVER';
        {% endcall %}

        {% set integration_name = load_result('integration_name')['data'] %}
        {{ log("Active integration: " ~ integration_name, True) }}

        {# /* If loop to check whether the tableau_server security integration already exists. If it exists, we move on with the 
            existsing name. If it does not exist, we create a new tableau_server security integration with the name we defined 
            in dbt_project.yml */ #}

        {% if integration_name|length %}
            {{ log("Active integration in if loop: " ~ integration_name, True) }}

        {% else %}
            
            {% set sql %}
            
                CREATE SECURITY INTEGRATION IF NOT EXISTS {{ new_integration_name }}
                TYPE = oauth
                ENABLED = true
                OAUTH_CLIENT = tableau_server;

            {% endset %}
            {% set table = run_query(sql) %}

            {% set integration_name = [(new_integration_name,)] %}

        {% endif %}

        {{ log("New set integration name: " ~ integration_name, True) }}

        {% for integration in integration_name %}

            {{ log("Integration in for loop: " ~ integration[0], True) }}

        {% endfor %}

        {# /* Creates a temporary snapshot of the description of the tableau_server security integration you defined/created before.
            This is used to extract the OAUTH AUTHORIZATION ENDPOINT. */ #}

        {% set sql %}

            CREATE OR REPLACE TEMPORARY TABLE SNAPSHOT_INTEGRATIONS_PROPERTIES (
            SNAPSHOT_DATE TIMESTAMP,
            INTEGRATION_PROPERTY VARCHAR,
            INTEGRATION_PROPERTY_TYPE VARCHAR,
            INTEGRATION_PROPERTY_VALUE VARCHAR,
            INTEGRATION_PROPERTY_DEFAULT VARCHAR);

            desc security integration {% for integration in integration_name %} {{integration[0]}} {% endfor %};
            insert into SNAPSHOT_INTEGRATIONS_PROPERTIES (SNAPSHOT_DATE,INTEGRATION_PROPERTY,INTEGRATION_PROPERTY_TYPE,INTEGRATION_PROPERTY_VALUE,INTEGRATION_PROPERTY_DEFAULT)
            SELECT CURRENT_TIMESTAMP() AS SNAPSHOT_DATE, * 
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

        {% endset %}
        {% set table = run_query(sql) %}

        {% call statement('integration_property', fetch_result=True) %}
            SELECT INTEGRATION_PROPERTY_VALUE FROM SNAPSHOT_INTEGRATIONS_PROPERTIES WHERE INTEGRATION_PROPERTY='OAUTH_AUTHORIZATION_ENDPOINT';
        {% endcall %}

        {% set integration_property = load_result('integration_property')['data'] %}
        {{ log("OAUTH ENDPOINT: " ~ integration_property, True) }}
        
    {% else %}
        {{ log("YOU DO NOT HAVE THE PRIVILEGES TO CREATE OR DESCRIBE SECURITY INTEGRATIONS", True) }}

    {% endif %}

{% endmacro %}