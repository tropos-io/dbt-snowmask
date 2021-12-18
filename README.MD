## Introduction
This repo contains the following macros:

- `masking_policy.sql` to create, alter and apply masking policies in Snowflake using DBT.
[Here](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro.html), you can find some info on Dynamic Data Masking in Snowflake.

- `row_column_masked_view.sql` to create an interactive view with row-level security.

- `create_security_integration.sql` to create/check a security integration with tableau server and ask for the OAUTH endpoint.

<br />

## **IMPORTANT**
Since dynamic data masking and row-level security are security measures, not every role or every user can create and alter the masking policies or RLS-views. This role has to have the privileges to define, manage, and apply masking policies to columns. It is best to have a specific role for this that is not used for anything else.

<br />

## Masking policy ([source](macros/masking_policy.sql))
This macro creates, alters and applies masking policies.


### Installation instructions
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


#### Usage:
```
{{ dbt_asana.masking_policy([('table_name','column_name)], ('roles_1'), ('roles_2')) }}
```
 **'table_name'**: table name of the column you want masked\
 **'colum_name'**: column name of the column you want masked\
 **'roles_1'**: name(s) of the role(s) you want to have full access\
 **'roles_2'**: name(s) of the role(s) you want to have limited access


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

<br />

## Row-level security ([source](macros/row_column_masked_view.sql))
This macro creates a row-level secured view from a table. It uses a csv file with the 'key | user' combination to decide which user can access which row.


### Installation instructions
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
  - "{{ dbt_asana.row_column_masked_view('table_name', 'source_schema', 'source_table', 'key_table', 'key_csv', 'user_csv', 'control_user') }}"

```

4. Include a `sources.yml` file in your ./models folder where you define the source of your csv file(s). You can find more info on this [here](https://docs.getdbt.com/reference/dbt-jinja-functions/source/).

```YAML
# sources.yml
version: 2

sources:
  - name: <source_schema>
    tables:
      - name: <source_table>

```

5. Execute `dbt seed` – the information in the csv file will be turned into a table in your active schema. The table automatically gets the name of your csv file. If your macro has been added with an on-run-end command, it will automatically be run after your `dbt seed`.
6. Optionally, execute `dbt run` if you want to run a model.


#### Usage:
```
{{ dbt_asana.row_column_masked_view('table_name', 'source_schema', 'source_table', 'key_table', 'key_csv', 'user_csv', 'control_user') }}
```
 **'table_name'**: table name of the table you want to create your view on\
 **'source_schema'**: schema name that has been defined in your `sources.yml`\
 **'source_table'**: table name that has been defined in your `sources.yml`\
 **'key_table'**: key of the table you want to filter on\
 **'key_csv'**: column name of the key in the csv file\
 **'user_csv'**: column name of the users in the csv file\
 **'control_user'**: a user that is allowed access to all rows


#### Information:
- This macro uses the active database and schema defined in your `profiles.yml`.
- Your csv file should be in your ./data folder.


#### Example:

```YAML
# dbt_project.yml
on-run-end:
  - "{{ dbt_asana.row_column_masked_view('BILLS', 'SALES', 'RLS_RULES', 'ID', 'ID_NUMBER', 'USER', 'USER_000') }}"
```

In this example, the row-level security will be set on the combination of the ID and USER. For example, if the csv file would look like the table below, USER_AAA would only see the rows of the table 'BILLS' that have the ID 111. In the same way USER_BBB would only see the rows with the ID 222. USER_000 (e.g., the supervisor), would see all rows with ID's defined in the csv file.

ID_NUMBER | USER
------------ | -------------
111 | USER_AAA
222 | USER_BBB

<br />

## Combining masking policy and row-level security
Ideally you would run both macro's together.

```YAML
# dbt_project.yml
on-run-end:
  - "{{ dbt_asana.masking_policy([('<table_name','<column_name>'),('<table_name','<column_name>')], 
        ('<roles_1>'),
        ('<roles_2>')) }}"
  - "{{ dbt_asana.row_column_masked_view('table_name', 'source_schema', 'source_table', 'key_table', 'key_csv', 'user_csv', 'control_user') }}"
```

You first mask your columns based on the roles you have defined. Then you would use row-level security to create views on these masked tables for extra security and privacy. This way you have masking based on roles and users.

<br />

## Creating security integrations ([source](macros/create_security_integration.sql))
This macro creates a security integration for tableau server when no current security integration for tableau server exists. It also returns the OAUTH endpoint of this newly created security integration. When a security integration already exists, it returns the OAUTH endpoint of the existing security integration.

## **IMPORTANT**
This macro can only be run by a user with the privileges to use the role ACCOUNTADMIN. Otherwise, a message saying 'YOU DO NOT HAVE THE PRIVILEGES TO CREATE OR DESCRIBE SECURITY INTEGRATIONS' will be returned.

### Installation instructions
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
 - "{{ dbt_asana.create_security_integration('new_integration_name') }}"

```

4. Execute `dbt run` – the security integration will be created/checked and the OAUTH endpoint will be returned (if you have the right privileges)!


#### Usage:
```
{{ dbt_asana.create_security_integration('new_integration_name') }}
```
 **'new_integration_name'**: name of the new security integration for tableau server you want to create


#### Information:
- This macro will only work when you have the privileges to use the role ACCOUNTADMIN!
- This macro is only designed for tableau server security integrations.


#### Example:

```YAML
# dbt_project.yml
on-run-end:
  - "{{ dbt_asana.create_security_integration('new_tableau_server_integration') }}"
```

In this example the macro will first check whether the current user can use the role ACCOUNTADMIN. If they can't, the message 'YOU DO NOT HAVE THE PRIVILEGES TO CREATE OR DESCRIBE SECURITY INTEGRATIONS' will be returned. If they can use the role ACCOUNTADMIN, the macro will check whether a security integration for tableau server already exists. If it does, the OAUTH endpoint for the existing security integration will be returned. If it doesn't exist, a new security integration will be created with the name 'new_tableau_server_integration' and the OAUTH endpoint of this new security integration will be returned.

<br />

## Database support
This package has been tested on Snowflake.

## License
Licensed under the GNU GPLv3 license (see LICENSE.md file for more details).

