# DBT Base runner container
(c) 2019 by Tropos.io

# Status
[![Container built and pushed to ECR](https://github.com/jvdborre/dbt-base/workflows/Baseline%20DBT%20Container%20CI%20on%20ECR/badge.svg)](http://unmaintained.tech/)



## Introduction
A container that runs and  deploys a DBT (http://www.getdbt.com) model and deploys it to a data warehouse.

## Usage

* * Container can be parametrized by setting the container environment variables outlined below
```
Docker run ...
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| REPO | Name of the task | string | n/a | yes |
| GIT_RSA | Private key to access the git repository | string | n/a | yes |
| DB_RSA | Private key to access Snowflake | string |  n/a | yes |
| DB_USERNAME | Username to access Snowflake | string |  n/a | yes |

 
