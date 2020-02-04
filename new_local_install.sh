# need to create `postgres` user
if ! `docker exec -T postgresql psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q "1"`; then
    echo "  > Creating 'postgres' user";
    docker exec -T postgresql createuser -s --username=mms postgres;

    if [ `docker exec -T postgresql psql -U mms postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'"` == 1 ]; then
        echo "  > Successfully created 'postgres' user";
    else
        echo -e "  \033[0;31m> Error creating 'postgres' user\033[0m"; #error in red text (https://stackoverflow.com/a/5947802/5094375)
    fi
else
    echo "  > User 'postgres' already exists";
fi

# fix bad permissions
echo ">>> Fixing bad permissions in Elasticsearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /tmp/elasticresearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "chown -R elasticresearch:elasticresearch /var/data";

#update mss-mappings
echo ">>> Fixing bad permissions in Elasticsearch";
docker exec -it --priviledged=true -u root v342-elastic sh -c "mms-mappings.sh" < /vagrant/mms-mappings.sh;

#restart
echo ">>> restarting Elasticsearch";
docker restart v342-elastic;

echo ">>> copy correct config files to vagrant vm...";
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/alfresco-global.properties" < alfresco-global.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/shared/classes/mms.properties" < mms.properties;
docker exec -i v342-mms sh -c "cat > /usr/local/tomcat/conf/tomcat-users.xml" < tomcat-users.xml;
