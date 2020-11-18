## Introduction

This repo contains the macro `masking_policy.sql` to create, alter and apply masking policies in Snowflake using DBT.
[Here](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro.html), you can find some info on Dynamic Data Masking in Snowflake.



## Installation instructions
New to dbt packages? Read more about them [here](https://docs.getdbt.com/docs/building-a-dbt-project/package-management/).
1. Include this package in your `packages.yml` — check [here](https://github.com/tropos-io/dbt-asana/releases) for the latest version number.

```YAML
# packages.yml
packages:
  - git: "https://github.com/tropos-io/dbt-asana.git"
    revision: <latest version>

```

2. Run `dbt deps`
3. Include the macro in your `dbt_project.yml`. This can be added with a hook, on-run-end...

```YAML
# dbt_project.yml
on-run-end:
  - "{{ dbt_asana.masking_policy([('<table_name','<column_name>'),('<table_name','<column_name>')], 
        ('<roles_1>'),
        ('<roles_2>')) }}"

```
In this package you have to add the column you want masked together with the table this column belongs to. You can add just one column or multiple columns. 
The roles are created in 2 levels. Every role in 'roles_1' has full access to the masked data, the roles in 'roles_2' have access to hashed values for string data. The roles that are not mentioned in this policy, will see '******' or NULL values.

4. Execute `dbt run` – the policies will be set automatically!



## Masking policy ([source](macros/masking_policy.sql))
This macro creates, alters and applies masking policies.

#### Usage:
```
{{ dbt_asana.masking_policy([('table_name','column_name)], ('roles_1'), ('roles_2')) }}
```
 
#### Information:
- It is good practice to create a specific role to create these masking policies. You can find more information on this [here](https://docs.snowflake.com/en/user-guide/security-column-ddm-use.html).
- This macro uses the active database and schema defined in your `profiles.yml`. 
- You can add just one or multiple columns from different tables, as long as they are in the same schema and database.
- You can add just one or multiple roles, and up to 2 masking levels.
- There are 3 kinds of policies: 1 for string values, 1 for date values, and 1 for number values. These will automatically be set for the matching columns.
- The roles have to exist before running this macro. 

#### Example:

```YAML
# dbt_project.yml
on-run-end:
  - "{{ dbt_asana.masking_policy([('IDENTIFIERS','NAME'), ('IDENTIFIERS','FIRST_NAME'), ('PRIVATE','ADDRESS')], 
        ('DIRECTOR','MANAGER'),
        ('JUNIOR')) }}"
```

In this example, the masking policy will be set on the name, first name and address columns. The director and manager roles will have full access to the masked columns (i.e., will see the values), the junior role will see hashed values for these columns, and the roles that are not mentioned will see '********'.



## Database support
This package has been tested on Snowflake.
