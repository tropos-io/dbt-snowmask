export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

now=$(date +"%Y-%m-%d")
UploadPath=s3://311701907485-dbtdocs

dbt deps
dbt test
dbt compile
dbt docs generate
aws s3 cp ./target $UploadPath --recursive
