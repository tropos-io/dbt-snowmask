#!/usr/bin/env bash

echo GIT_RSA > private.key
echo DB_RSA > private.key



git clone $REMOTE_REPO
cd $REPO_DIR
dbt deps --profiles-dir .
dbt docs generate --target prod --profiles-dir .
dbt docs serve --profiles-dir . > /dev/null 2>&1 &
while [ True ]
do
    sleep 600
    if [ `git rev-parse --short HEAD` != `git rev-parse --short origin/master` ]; then
        git fetch --all
        git reset --hard origin/master
        dbt deps --profiles-dir .
        dbt docs generate --target prod --profiles-dir .
    fi
done
