# DBT Base runner container
(c) 2019 by Tropos.io


## Introduction

This repo contains a macro to create, alter and apply masking policies.


#### masking policy ([source](macros/masking_policy.sql))
This macro creates, alters and applies masking policies.

Usage:
```
{{ masking_policy([('table_name','column_name)], ('role_group_1'), ('role_group_2')) }}
```
 