############################################################
# Dockerfile to build a DBT execution container
# DATE: 1/10/2019
# COPYRIGHT: tropos.io
############################################################

# Set the base image
FROM python:3.9.0

###################################################################
#*******************    CONTAINER BUILD   *************************
###################################################################

# configure versions
ARG AWSCLI_VERSION=1.16.258
ARG DBT_VERSION=0.18.1
# Following 2 parameters will be mapped on a variable and a secret through
# an ECS task. Assigned values are placeholders.

ENV DBT_USER=NONE
ENV DBT_PASSWORD=NONE

# Create appropriate folder structure to host the DBT content.

ARG user=dbt
ARG homedir=/home/${user}

RUN mkdir ${homedir}
COPY . ${homedir}/
COPY run.sh ${homedir}/

# Install prerequisites for DBT
RUN pip3 install --upgrade pip \
    && pip3 install dbt==$DBT_VERSION \
    && pip3 install awscli==$AWSCLI_VERSION

# Set DBT-specific environment variable so we can keep
# the profiles.yml file in the git repository.

ENV DBT_PROFILES_DIR=${homedir}


###################################################################
#************** CODE EXECUTED ON CONTAINER EXECUTION **************
###################################################################

# Set the working directory to the dbt content folder.
WORKDIR ${homedir}

# Define what needs to happen when the container is executed.
CMD [ "sh", "-c", "./run.sh" ]
