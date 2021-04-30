cd ~

########
export NAKSHA_CONFIG_PATH=/apps/config.properties
export GS_TMPDIR=/apps/naksha/map_upload_tmp/
export GS_DIR=/apps/naksha/geoserver_data_dir
export GS_WORKSPACE=biodiv
export GS_STORE=ibp

export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=ibp

export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres123
########

mkdir -p $GS_TMPDIR
mkdir -p $GS_DIR

GS_VERSION=2.17.1
WAR_URL='https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/'${GS_VERSION}'/geoserver-'${GS_VERSION}'-war.zip'
PLUGIN_GDAL='https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/'${GS_VERSION}'/extensions/geoserver-'${GS_VERSION}'-gdal-plugin.zip'
PLUGIN_VECTOR='https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/'${GS_VERSION}'/extensions/geoserver-'${GS_VERSION}'-vectortiles-plugin.zip'

mkdir ~/geoserver-tmp
cd geoserver-tmp

wget $WAR_URL
unzip -q geoserver-*
unzip -q geoserver.war -d geoserver-binary
mv ~/naksha-docker/backend/web.xml geoserver-binary/WEB-INF/web.xml
cd geoserver-binary/WEB-INF/lib
wget $PLUGIN_GDAL
wget $PLUGIN_VECTOR
unzip -q -o "*.zip"
rm -rf *.zip

cd ../../
zip -q -r ../geoserver.war .

mkdir -p ~/tomcat
cd ~/tomcat
chmod +x ./bin/*.sh
wget https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.43/bin/apache-tomcat-8.5.43.zip
unzip -q -o "*.zip"
mv ~/geoserver-tmp/geoserver.war ./apache-tomcat-8.5.43/webapps

cd ~/naksha
chmod +x ./gradlew
rm ~/naksha/src/main/resources/config.properties
cp ~/naksha-docker/backend/config.properties $NAKSHA_CONFIG_PATH


##############################################
export GS_ENDPOINT="http://localhost:8080/geoserver"
export GS_BASIC_AUTH="admin:geoserver"
export GS_INTERNAL_USER="nakshauser"
export GS_INTERNAL_PASSWORD=$(date '+%s')

export DB_USER=$POSTGRES_USER
export DB_PASSWORD=$POSTGRES_PASSWORD

# Start Tomcat
printf "🐈\tStarting Tomcat\n"
mkdir -p "$GS_TMPDIR"
mkdir -p "$GS_DIR"
mkdir -p "$GS_DIR/gwc-layers"
chmod +x ~/tomcat/apache-tomcat-8.5.43/bin/*.sh
sh ~/tomcat/apache-tomcat-8.5.43/bin/catalina.sh start


until [ "`curl --silent --show-error --connect-timeout 1 \"${GS_ENDPOINT}/web/\" | grep 'GeoServer instance is running'`" != "" ];
do
  printf "🕓 Waiting for GeoServer to start..."
  sleep 5
done
printf "🌐\tGeoServer is Ready"

# Create internal user
printf "\n🤖\tCreating internal user with name ${GS_INTERNAL_USER}"
curl -X POST \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/security/usergroup/users/" \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
	"org.geoserver.rest.security.xml.JaxbUser":{
		"userName": "'$GS_INTERNAL_USER'",
		"password": "'$GS_INTERNAL_PASSWORD'",
		"enabled": true
	}
}'


# Make internal user admin
curl -X POST \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/security/roles/role/ADMIN/user/${GS_INTERNAL_USER}" \
  -H 'cache-control: no-cache'




# Create Workspace
printf "\n📚\tCreating workspace "
curl -X POST \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/workspaces" \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
	"workspace": {
		"name": "'$GS_WORKSPACE'"
	}
}'

printf "\n⚙\tUpdating worksapace configuration"
# Update Workspace Configuration
curl -X PUT \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/services/wfs/workspaces/${GS_WORKSPACE}/settings" \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{"wfs":{"workspace":{"name":"'$GS_WORKSPACE'"},"enabled":true,"name":"WFS","versions":{"org.geotools.util.Version":[{"version":"1.0.0"},{"version":"1.1.0"},{"version":"2.0.0"}]},"citeCompliant":false,"schemaBaseURL":"http://schemas.opengis.net","verbose":false,"metadata":{"entry":[{"@key":"SHAPE-ZIP_DEFAULT_PRJ_IS_ESRI","$":"false"},{"@key":"maxNumberOfFeaturesForPreview","$":"50"}]},"gml":{"entry":[{"version":"V_11","gml":{"srsNameStyle":["URN"]}},{"version":"V_10","gml":{"srsNameStyle":["XML"]}},{"version":"V_20","gml":{"srsNameStyle":["URN2"]}}]},"serviceLevel":"COMPLETE","maxFeatures":1000000,"featureBounding":true,"canonicalSchemaLocation":false,"encodeFeatureMember":false,"hitsIgnoreMaxFeatures":false}}'



printf "\n📙\tCreating datastore "
# Create DataStore
curl -X POST \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/workspaces/${GS_WORKSPACE}/datastores" \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{"dataStore":{"name":"'$GS_STORE'","type":"PostGIS","enabled":true,"workspace":{"name":"'$GS_WORKSPACE'","href":"'$GS_ENDPOINT'/rest/workspaces/'$GS_WORKSPACE'.json"},"connectionParameters":{"entry":[{"@key":"schema","$":"public"},{"@key":"Evictor run periodicity","$":"300"},{"@key":"Max open prepared statements","$":"50"},{"@key":"encode functions","$":"true"},{"@key":"Batch insert size","$":"1"},{"@key":"preparedStatements","$":"false"},{"@key":"database","$":"'$DB_NAME'"},{"@key":"host","$":"'$DB_HOST'"},{"@key":"Loose bbox","$":"true"},{"@key":"Estimated extends","$":"true"},{"@key":"fetch size","$":"1000"},{"@key":"Expose primary keys","$":"false"},{"@key":"validate connections","$":"true"},{"@key":"Support on the fly geometry simplification","$":"true"},{"@key":"Connection timeout","$":"20"},{"@key":"create database","$":"false"},{"@key":"port","$":"'$DB_PORT'"},{"@key":"passwd","$":"'$DB_PASSWORD'"},{"@key":"min connections","$":"1"},{"@key":"dbtype","$":"postgis"},{"@key":"namespace","$":"http://'$GS_WORKSPACE'"},{"@key":"max connections","$":"10"},{"@key":"Evictor tests per run","$":"3"},{"@key":"Test while idle","$":"true"},{"@key":"user","$":"'$DB_USER'"},{"@key":"Max connection idle time","$":"300"}]},"_default":false}}'


printf "\n⚡\tUpdating Caching Defaults"
PAYLOAD=$(curl -u $GS_BASIC_AUTH "${GS_ENDPOINT}/rest/resource/gwc-gs.xml")

PAYLOAD=$(echo $PAYLOAD | sed -e "s/<defaultVectorCacheFormats>/<defaultVectorCacheFormats><string>application\/vnd.mapbox-vector-tile<\/string>/g")
PAYLOAD=$(echo $PAYLOAD | sed -e "s/<defaultOtherCacheFormats>/<defaultOtherCacheFormats><string>application\/vnd.mapbox-vector-tile<\/string>/g")

curl -X PUT \
  -u $GS_BASIC_AUTH \
  "${GS_ENDPOINT}/rest/resource/gwc-gs.xml" \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/xml' \
  -d "${PAYLOAD}"


printf "\n🔍\tSearching DataStore Id"
export GS_DATASTORE_ID=$(cat "${GS_DIR}/workspaces/${GS_WORKSPACE}/${GS_STORE}/datastore.xml" | \
  grep "DataStoreInfoImpl" | \
  sed -e 's/<[^>]*>//g' | \
  sed -e 's/^[ \t]*//')

printf "\n🔍\tSearching NameSapce Id"
export GS_NAMESPACE_ID=$(cat "${GS_DIR}/workspaces/${GS_WORKSPACE}/namespace.xml" | \
  grep "NamespaceInfoImpl" | \
  sed -e 's/<[^>]*>//g' | \
  sed -e 's/^[ \t]*//')



# Update Configurations to file
printf "\n🐿️\tWriting configuration to config file\n"
sed -i 's/__GS_ENDPOINT__/'$(echo ${GS_ENDPOINT} | sed -e "s#/#\\\/#g")'/g'   $NAKSHA_CONFIG_PATH
sed -i 's/__DB_NAME__/'$DB_NAME'/g'                                           $NAKSHA_CONFIG_PATH
sed -i 's/__DB_PASSWORD__/'$DB_PASSWORD'/g'                                   $NAKSHA_CONFIG_PATH
sed -i 's/__DB_USER__/'$DB_USER'/g'                                           $NAKSHA_CONFIG_PATH
sed -i 's/__GS_WEB_USER__/'$GS_INTERNAL_USER'/g'                              $NAKSHA_CONFIG_PATH
sed -i 's/__GS_WEB_PASSWORD__/'$GS_INTERNAL_PASSWORD'/g'                      $NAKSHA_CONFIG_PATH
sed -i 's/__DB_HOST__/'$DB_HOST'/g'                                           $NAKSHA_CONFIG_PATH
sed -i 's/__DB_PORT__/'$DB_PORT'/g'                                           $NAKSHA_CONFIG_PATH
sed -i 's/__GS_WORKSPACE__/'$GS_WORKSPACE'/g'                                 $NAKSHA_CONFIG_PATH
sed -i 's/__GS_STORE__/'$GS_STORE'/g'                                         $NAKSHA_CONFIG_PATH
sed -i 's/__GS_NAMESPACE_ID__/'$GS_NAMESPACE_ID'/g'                           $NAKSHA_CONFIG_PATH
sed -i 's/__GS_DATASTORE_ID__/'$GS_DATASTORE_ID'/g'                           $NAKSHA_CONFIG_PATH
sed -i 's/__GS_TMPDIR__/'$(echo ${GS_TMPDIR} | sed -e "s#/#\\\/#g")'/g'       $NAKSHA_CONFIG_PATH
sed -i 's/__GS_DIR__/'$(echo ${GS_DIR} | sed -e "s#/#\\\/#g")'/g'             $NAKSHA_CONFIG_PATH
sed -i 's/first.init=false/first.init=true/g'                                 $NAKSHA_CONFIG_PATH

cp $NAKSHA_CONFIG_PATH ~/naksha/src/main/resources/config.properties
# ./gradlew war
# mv build/libs/naksha.war ~/tomcat/apache-tomcat-8.5.43/webapps

echo "✨ Done ✨"
