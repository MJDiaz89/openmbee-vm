echo ">>> removing old docker containers";
docker rm -f v342-mms v342-elastic v342-activemq v342-solr v342-postgres;

echo ">>> docker-compose up..."
docker-compose up -d;
docker-compose logs --no-color > docker-compose-logs.txt;
echo ">>> docker-compose done. Logs saved to 'docker-compose-logs.txt'"


# ========= Postgres =========
# need to create `postgres` user
if ! `docker exec -it postgresql psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q "1"`; then
    echo "  > Creating 'postgres' user";
    docker exec -it postgresql createuser -s --username=mms postgres;

    if [ `docker exec -it postgresql psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'"` == 1 ]; then
        echo "  > Successfully created 'postgres' user";
    else
        echo -e "  \033[0;31m> Error creating 'postgres' user\033[0m"; #error in red text (https://stackoverflow.com/a/5947802/5094375)
    fi
else
    echo "  > User 'postgres' already exists";
fi


# ========= Elasticsearch =========
# fix bad  permissions
echo ">>> Fixing bad permissions in Elasticsearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /tmp/elasticresearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /var/data";

#update mss-mappings
echo ">>> Fixing bad permissions in Elasticsearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "mms-mappings.sh" < /vagrant/mms-mappings.sh;


# ========= MMS =========
echo ">>> copy correct config files to vagrant vm...";
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/alfresco-global.properties" < alfresco-global.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/mms.properties" < mms.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/conf/tomcat-users.xml" < tomcat-users.xml;


# ========= clean up =========
echo ">>> restarting all containers...";
docker restart  v342-elastic v342-activemq v342-solr v342-postgres v342-mms;
echo ">>> all containers restarted";