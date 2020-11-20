
{% macro row_column_masked_view(table_name, source_schema, source_table, key_table, key_csv, user_csv, control_user) %}


    CREATE OR REPLACE VIEW ROW_COLUMN_MASKED
    AS SELECT
        *
    FROM {{ target.database }}.{{ target.schema }}."{{ table_name }}"

    WHERE {{ key_table }} IN (SELECT {{ key_csv }}
        FROM {{ source(source_schema, source_table) }}
        WHERE (UPPER({{ user_csv }}) = CURRENT_USER()) OR (CURRENT_USER() = '{{ control_user }}'))

{% endmacro %}