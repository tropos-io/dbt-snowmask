export GIT_RSA=`cat ~/.ssh/id_rsa.pub`
export DB_RSA=`cat ~/.ssh/id_rsa.pub`
export REPO='git@bitbucket.org:tropos/tf-snowflake-privatelink.git'
echo awk -F/ '{print $3}' <<<$REPO

