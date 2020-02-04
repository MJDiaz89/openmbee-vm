#!/usr/bin/env bash
echo ">>> removing old docker containers";
docker rm -f v342-mms v342-elastic v342-activemq v342-solr v342-postgres;

echo ">>> docker-compose up..."
docker-compose up -d;
echo ">>> docker-compose done.'"


# ========= Postgres =========
# need to create `postgres` user
# if ! `docker exec -i v342-postgres psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q "1"`; then
#     echo "  > Creating 'postgres' user";
#     docker exec -i v342-postgres createuser -s --username=mms postgres;

#     if [[ `docker exec -i v342-postgres psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'"` == 1 ]]; then
#         echo "  > Successfully created 'postgres' user";
#     else
#         echo -e "  \033[0;31m> Error creating 'postgres' user\033[0m"; #error in red text (https://stackoverflow.com/a/5947802/5094375)
#     fi
# else
#     echo "  > User 'postgres' already exists";
# fi
# Check to see if new user has ability to create databases
PG_DB_CREATION_COMMAND="create table if not exists organizations (   id bigserial primary key,   orgId text not null,   orgName text not null,   constraint unique_organizations unique(orgId, orgName) ); create index orgId on organizations(orgId);  create table projects (   id bigserial primary key,   projectId text not null,   orgId integer references organizations(id),   name text not null,   location text not null,   constraint unique_projects unique(orgId, projectId) ); create index projectIdIndex on projects(projectid);"
if `docker exec -i v342-postgres psql -U mms -c "${PG_TEST_CREATEDB_ROLE_COMMAND}" | grep -q "(0 row)"`; then
    echo "  > Giving 'mms' permission to create databases"
    docker exec -i v342-postgres psql -U mms -c "ALTER ROLE mms CREATEDB"
fi

if ! `docker exec -i v342-postgres psql -lqt -U mms | cut -d \| -f 1 | grep -qw alfresco`; then
    echo "  > Creating the Alfresco database ('alfresco')"
    docker exec -i v342-postgres createdb -U mms alfresco
fi

if ! `docker exec -i v342-postgres psql -lqt -U mms | cut -d \| -f 1 | grep -qw mms`; then
    echo "  > Creating the MMS database ('mms')"
    docker exec -i v342-postgres createdb -U mms mms
fi

if ! `docker exec -i v342-postgres psql -U mms -d mms -c "\dt" | grep -qw organizations`; then
    docker exec -i v342-postgres psql -U mms -d mms -c "${PG_DB_CREATION_COMMAND}"
fi

# ========= Elasticsearch =========
# fix bad  permissions
# echo ">>> Fixing bad permissions in Elasticsearch...";
# docker exec -i --privileged=true -u root v342-elastic sh -c "chown -R elasticsearch:elasticsearch /tmp/elasticsearch";
# docker exec -i --privileged=true -u root v342-elastic sh -c "chown -R elasticsearch:elasticsearch /tmp/elasticsearch/nodes";
# docker exec -i --privileged=true -u root v342-elastic sh -c "chown -R elasticsearch:elasticsearch /var/data";
# docker exec -i --privileged=true -u root v342-elastic sh -c "chown -R elasticsearch:elasticsearch /var/data/nodes";

#update mss-mappings
echo ">>> Copying correct config files to Elasticsearch...";
#docker exec -i --privileged=true -u root v342-elastic sh -c "cat > mms-mappings.sh" < mms-mappings.sh;
sleep 10;
echo " >> Uploading MMS Mapping Template File to Elasticsearch..."
ES_RESPONSE=$(curl -XPUT http://127.0.0.1:9200/_template/template -H "Content-iype: application/json" -d @mapping_template.json)
if [ "${ES_RESPONSE}" == "{\"acknowledged\":true}" ] 
then
    echo "  > Successfully uploaded MMS Template to Elasticsearch"
else
    echo "  > Failed to upload the MMS Template to Elasticsearch"
fi

# ========= MMS =========
echo ">>> Copying correct config files to tomcat...";
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/alfresco-global.properties" < alfresco-global.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/mms.properties" < mms.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/conf/tomcat-users.xml" < tomcat-users.xml;


# ========= clean up =========
echo ">>> Restarting all containers...";
docker restart v342-elastic v342-activemq v342-solr v342-postgres v342-mms;
echo ">>> All containers restarted";

echo ">>> Sleeping to allow all containers to restart...";
sleep 30;

docker-compose logs --no-color > docker-compose-logs.txt;
echo ">>> docker-compose logs saved to 'docker-compose-logs.txt'"
