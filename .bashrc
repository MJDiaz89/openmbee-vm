#!/usr/bin/env bash
set -a
. /vagrant/.env
set +a

alias dc='${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant'

commands() {
  cat << EOF

MMS VM Custom Commands Help:

    clean_restart      - remove all containers and volumes and restart containers
    dc                 - function alias for docker-compose (alias for 'docker-compose -f /vagrant/docker-compose.yml')
    enter <container>  - shell into a running container (e.g., 'enter db' to enter the PostgreSQL container)
    initialize_db      - populate the PostgreSQL service with the necessary permissions and databases
    initialize_search  - populate the Elasticsearch service by uploading the MMS Mapping Template
    setup              - start stopped services and (if necessary) initialize their data
    teardown           - remove all containers and volumes

EOF
}

enter() {
    ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec "${1}" env TERM=xterm /bin/sh
}

setup() {
    echo ">>> Creating required volumes"
    docker volume create alf_logs
    docker volume create alfresco-data-volume
    docker volume create postgres-data-volume
    docker volume create activemq-data-volume
    docker volume create activemq-log-volume
    docker volume create activemq-conf-volume
    docker volume create elastic-data-volume
    docker volume create nginx-external-volume
    
    echo ">>> Starting containerized services"
    ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant up -d

    echo ">>> Initializing the database service (PostgreSQL)"
    initialize_db

    echo ">>> Initializing the search service (Elasticsearch)"
    initialize_search
    # echo ""

    #transfer the corrected files to the docker tomcat directories:
    #the .properties files change Alfresco to use the HTTP protocol instead of the HTTPS (the default); the tomcat-users files creates necessary admin user
    #after files are written, restart openmbee-mms container for changes to take effect
    echo ">>> copy correct config files to vagrant vm..."
    docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/alfresco-global.properties" < /vagrant/alfresco-global.properties
    docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/mms.properties" < /vagrant/mms.properties
    docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/conf/tomcat-users.xml" < /vagrant/tomcat-users.xml
    docker restart v342-mms

    #coerce (again) Postgres to create the required `alfresco` and `mms` databases
    # echo ">>> ensuring the necessary databases were created"
    #initialize_db

    echo ">>> You can now use 'dc logs' to inspect the services"
}

teardown() {
    ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant stop
    ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant kill
    ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant rm -f -v
    docker system prune -f
    docker volume prune -f
    # if [[ -f ${ES_MAPPING_TEMPLATE_FILE} ]]; then
    #     rm ${ES_MAPPING_TEMPLATE_FILE}
    # fi
}

clean_restart() {
    teardown
    setup
}

initialize_db() {
    if ! [[ `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant ps -q ${PG_SERVICE_NAME}` ]]; then
        echo "  > Waiting ${PG_WAIT} seconds for PostgreSQL service to start"
        sleep ${PG_WAIT}
    fi

    # Check to see PostgreSQL service is running by requesting list of available databases
    if ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -lq -U ${PG_DB_NAME} | grep -q "List of databases"`; then
        echo "  > Waiting ${PG_WAIT} seconds for PostgreSQL to begin accepting connections"
        sleep ${PG_WAIT}
    fi

    # need to create `postgres` user
    if ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q "1"`; then
        echo "  > Creating 'postgres' user"
        ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} createuser -s --username=${PG_DB_NAME} postgres

        if [ `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'"` == 1 ]; then
            echo "  > Successfully created 'postgres' user"
        else
            echo -e "  \033[0;31m> Error creating 'postgres' user\033[0m" #error in red text (https://stackoverflow.com/a/5947802/5094375)
        fi
    else
        echo "  > User 'postgres' already exists"
    fi

    # Check to see if new user has ability to create databases
    if `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} -c "${PG_TEST_CREATEDB_ROLE_COMMAND}" | grep -q "(0 row)"`; then
        echo "  > Giving '${PG_DB_NAME}' permission to create databases"
        ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} -c "ALTER ROLE ${PG_DB_NAME} CREATEDB"
    fi

    if ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -lqt -U ${PG_DB_NAME} | cut -d \| -f 1 | grep -qw alfresco`; then
        echo "  > Creating the Alfresco database ('alfresco')"
        ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} createdb -U ${PG_DB_NAME} alfresco
    fi

    if ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -lqt -U ${PG_DB_NAME} | cut -d \| -f 1 | grep -qw ${PG_DB_NAME}`; then
        echo "  > Creating the MMS database ('${PG_DB_NAME}')"
        ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} createdb -U ${PG_DB_NAME} ${PG_DB_NAME}
    fi

    if ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} -d ${PG_DB_NAME} -c "\dt" | grep -qw organizations`; then
        ${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant exec -T ${PG_SERVICE_NAME} psql -U ${PG_DB_NAME} -d ${PG_DB_NAME} -c "${PG_DB_CREATION_COMMAND}"
    fi
}

initialize_search() {
    if [[ ! `${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant ps -q ${ES_SERVICE_NAME}` ]]; then
        echo "  > Waiting ${ES_WAIT} seconds for Elasticsearch service to start"
        sleep ${ES_WAIT}
    fi

    if [[ ! -f ${ES_MAPPING_TEMPLATE_FILE} ]]; then
        echo "  > Could not find '${ES_MAPPING_TEMPLATE_FILE}'!"
        echo "  > Attempting to download the Elasticsearch Mapping File from the OpenMBEE MMS GitHub Repo"
        wget -O ${ES_MAPPING_TEMPLATE_FILE} ${ES_MAPPING_TEMPLATE_URL}
    fi

    ES_RESPONSE=`curl -s -XGET http://127.0.0.1:${ES_PORT}/_template/template`
    if [[ "${ES_RESPONSE:0:1}" != "{" ]]; then
        echo "  > Sleeping to make sure Elasticsearch is running"
        sleep ${ES_WAIT}

        echo "  > Re-requesting template from Elasticsearch"
        ES_RESPONSE=`curl -s -XGET http://127.0.0.1:${ES_PORT}/_template/template`
    fi

    # if [[ "${ES_RESPONSE}" == "{}" ]]; then
    #     echo " >> Uploading MMS Mapping Template File to Elasticsearch"
    #     curl -XPUT http://127.0.0.1:${ES_PORT}/_template/template -d @${ES_MAPPING_TEMPLATE_FILE}

    #     ES_RESPONSE=`curl -s -XGET http://127.0.0.1:${ES_PORT}/_template/template`
    #     if [[ "${ES_RESPONSE}" == "{}" ]]; then
    #         echo ""
    #         echo ">>> Failed to upload the MMS Template to Elasticsearch"
    #     fi
    # fi

    # fix bad permissions
    echo ">>> Fixing bad permissions in Elasticsearch"
    docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /tmp/elasticresearch"
    docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /var/data"

    #update mss-mappings
    echo ">>> Fixing bad permissions in Elasticsearch"
    docker exec -it --priviledged=true -u root v342-elastic sh -c "mms-mappings.sh" < /vagrant/mms-mappings.sh
    
    #restart
    echo ">>> restarting Elasticsearch"
    docker restart v342-elastic
}
