#!/usr/bin/env bash

set -eo pipefail

_term() {
  echo "killing tomcat with TERM"
  kill -TERM "$tomcat_pid"
  while true; do
    set +e
      kill -0 "$tomcat_pid" 2>/dev/null || break
    set -e

    echo "tomcat still alive"
    sleep 1
  done

  echo "tomcat exited, exit 0"
  exit 0
}

trap _term SIGTERM

echo "Liferay starting.."

if [ -f ./liferay-env ]; then
  echo "env: ./liferay-env found, sourcing"
  # shellcheck disable=SC1091
  . "./liferay-env"
else
  echo "env: ./liferay-env not found"
fi

echo "check: required ENV variables"
required_envs_set="yes"

for var in DATABASE_HOST DATABASE_NAME DATABASE_USERNAME DATABASE_PASSWORD SESSION_REDIS_HOST; do
  if [ -z "${!var}" ] ; then
    echo "$var is not defined"
    required_envs_set="no"
  fi
done

if [ "$required_envs_set" = "no" ]; then
  echo ""
  echo "ERROR: some required ENV was not set, will hang now."
  tail -f /dev/null
fi

#------------------
export DATABASE_PORT=${DATABASE_PORT:-5432}
export SESSION_REDIS_PORT=${SESSION_REDIS_PORT:-6379}
export SESSION_SYNC=${SESSION_SYNC:-false}
export SESSION_SYNC_TIMEOUT=${SESSION_SYNC_TIMEOUT:-1000}

export ELASTICSEARCH_REST_HOST=${ELASTICSEARCH_REST_HOST:-elasticsearch}
export ELASTICSEARCH_REST_PORT=${ELASTICSEARCH_REST_PORT:-9200}
export ELASTICSEARCH_NODE_HOST=${ELASTICSEARCH_NODE_HOST:-elasticsearch}
export ELASTICSEARCH_NODE_PORT=${ELASTICSEARCH_NODE_PORT:-9300}

export ELASTICSEARCH_NUMBER_OF_SHARDS=${ELASTICSEARCH_NUMBER_OF_SHARDS:-1}
export ELASTICSEARCH_NUMBER_OF_REPLICAS=${ELASTICSEARCH_NUMBER_OF_REPLICAS:-0}

export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL="jdbc:postgresql://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}"
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME="${DATABASE_USERNAME}"
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD="${DATABASE_PASSWORD}"

export LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ENABLED=false
export LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ADD_PERIOD_SAMPLE_PERIOD_DATA=false

export LIFERAY_LIFERAY_PERIOD_HOME=/app
export LIFERAY_ADMIN_PERIOD_EMAIL_PERIOD_FROM_PERIOD_ADDRESS=admin@liferay.com
export LIFERAY_ADMIN_PERIOD_EMAIL_PERIOD_FROM_PERIOD_NAME="Liferay Admin"
export LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_LOCALE=en_US

export LIFERAY_DEFAULT_PERIOD_ADMIN_PERIOD_EMAIL_PERIOD_ADDRESS_PERIOD_PREFIX=canopi

export LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED=true
export LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/app/jgroups_jdbc_ping.xml
export LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_=/app/jgroups_jdbc_ping.xml

export LIFERAY_WEB_PERIOD_SERVER_PERIOD_PROTOCOL=https
export LIFERAY_WEB_PERIOD_SERVER_PERIOD_DISPLAY_PERIOD_NODE=true
export LIFERAY_REDIRECT_PERIOD_URL_PERIOD_SECURITY_PERIOD_MODE=domain
export LIFERAY_REDIRECT_PERIOD_URL_PERIOD_DOMAINS_PERIOD_ALLOWED=

export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME=org.postgresql.Driver

# explicitely fall back to java default of 137 gigabytes unless set
export MEMORY_LIMIT_BYTES="${MEMORY_LIMIT_BYTES:-137438953472}"

java_max_ram_bytes=$(expr ${MEMORY_LIMIT_BYTES} - ${MEMORY_LIMIT_BYTES} / 10)
export MEMORY_LIMIT_MAX="${java_max_ram_bytes}"


##  Hikari values are ms
# connectionTimeout
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_CONNECTION_UPPERCASET_IMEOUT=10000
# idleTimeout (minimum: 10000ms)
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_IDLE_UPPERCASET_IMEOUT=10000
# maxLifetime (minimum: 30000ms)
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAX_UPPERCASEL_IFETIME=30000
# maximumPoolSize
# NOTE: 2x due two hikari connection pools

export DATABASE_MAXCONNS="${DATABASE_MAXCONNS:-10}"
database_maxconns_divided=$(expr "${DATABASE_MAXCONNS}" / 2)
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAXIMUM_UPPERCASEP_OOL_UPPERCASES_IZE="${database_maxconns_divided:-5}"

#minimum_database_threads=$(expr ${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAXIMUM_UPPERCASEP_OOL_UPPERCASES_IZE} - ${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAXIMUM_UPPERCASEP_OOL_UPPERCASES_IZE} / 10)

# minimumIdle (set to maximumPoolSize by default unless set)
export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MINIMUM_UPPERCASEI_DLE="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MINIMUM_UPPERCASEI_DLE:-$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAXIMUM_UPPERCASEP_OOL_UPPERCASES_IZE}"

# echo "debug: envs"
# export

#-----------------

_xmlEscape () {
    s=${1//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//'"'/&quot;}
    echo "$s"
}

echo "create: /app/jgroups_jdbc_ping.xml"
jgroups_template=$(cat /app/jgroups_jdbc_ping.template.xml)

xml_escaped_jgroups_password=$(_xmlEscape $LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD)

jgroups_template="${jgroups_template//"LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME"/"$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME"}"
jgroups_template="${jgroups_template//"LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL"/"$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL"}"
jgroups_template="${jgroups_template//"LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME"/"$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME"}"
jgroups_template="${jgroups_template//"LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD"/"$xml_escaped_jgroups_password"}"

echo "$jgroups_template" > /app/jgroups_jdbc_ping.xml

#---------------------------
echo "override: tomcat default setenv.sh"
echo "" > /app/tomcat-9.0.10/bin/setenv.sh

#---------------------------
echo "configure: redis session manager to tomcat"
_tomcat_session_manager() {
  cat <<EOF
<!-- appended by /app/entrypoint.sh -->
<Manager className="de.javakaffee.web.msm.MemcachedBackupSessionManager" memcachedNodes="redis://${SESSION_REDIS_HOST}:${SESSION_REDIS_PORT}" sticky="true" sessionBackupAsync="${SESSION_SYNC}" sessionBackupTimeout="${SESSION_SYNC_TIMEOUT}" requestUriIgnorePattern=".*.(ico|png|gif|jpg|css|js|jpeg|webp)$" />
</Context>
EOF
}

tomcat_root_xml_path="/app/tomcat-9.0.10/conf/Catalina/localhost/ROOT.xml"
tomcat_root_xml=$(cat ${tomcat_root_xml_path})
tomcat_root_xml="${tomcat_root_xml//"</Context>"/"$(_tomcat_session_manager)"}"
echo "${tomcat_root_xml}" > "${tomcat_root_xml_path}"


#----------------------
echo "configure: liferay to use elasticsearch at ${ELASTICSEARCH_NODE_HOST}:${ELASTICSEARCH_NODE_PORT}"
elasticsearch_config_path="/app/osgi/configs/com.liferay.portal.search.elasticsearch6.configuration.ElasticsearchConfiguration.cfg"
mkdir -p "$(dirname ${elasticsearch_config_path})"

echo "# generated in /app/entrypoint.sh" > $elasticsearch_config_path
{
  echo "operationMode=REMOTE"
  echo "transportAddresses=${ELASTICSEARCH_NODE_HOST}:${ELASTICSEARCH_NODE_PORT}"
  echo "indexNumberOfShards=${ELASTICSEARCH_NUMBER_OF_SHARDS}"
  echo "indexNumberOfReplicas=${ELASTICSEARCH_NUMBER_OF_REPLICAS}"
} >> $elasticsearch_config_path

while true; do
  echo "wait: ${DATABASE_HOST}:${DATABASE_PORT}"
  export PGPASSWORD="$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD"
  echo "\conninfo" | psql -h "$DATABASE_HOST" -U "$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME" -d postgres && break
  sleep 1
done

while true; do
  echo "wait: ${ELASTICSEARCH_REST_HOST}:${ELASTICSEARCH_REST_PORT}"
  nc -w 1 -z "${ELASTICSEARCH_REST_HOST}" "${ELASTICSEARCH_REST_PORT}" && break
  sleep 1
done

echo "assert: elasticsearch plugins"
elasticsearch_analysis_plugins_count=$(curl --silent "${ELASTICSEARCH_REST_HOST}:${ELASTICSEARCH_REST_PORT}/_cat/plugins" | grep -c "analysis-")
if [ "$elasticsearch_analysis_plugins_count" != "4" ]; then
  echo "elasticsearch does not have 4 analysis plugins, exit 1 in 10s"
  sleep 10
  exit 1
fi

echo "workaround: elasticsearch liferay-0 template bug"
# bug: liferay-0 index uses 5 shards if deleted https://issues.liferay.com/browse/LPS-94002
_elasticsearch_template_post_data() {
  cat <<EOF
{
  "index_patterns": ["liferay-0"],
  "settings": {
    "number_of_shards": "${ELASTICSEARCH_NUMBER_OF_SHARDS}",
    "number_of_replicas": "${ELASTICSEARCH_NUMBER_OF_REPLICAS}"
  }
}
EOF
}
curl --silent -X PUT \
  -H "Content-Type: application/json" \
  -d "$(_elasticsearch_template_post_data)" \
  "${ELASTICSEARCH_REST_HOST}:${ELASTICSEARCH_REST_PORT}/_template/default"
echo ""

#-------------
echo "set: _JAVA_OPTIONS"
# Dorg.apache.catalina.loader.WebappClassLoader.ENABLE_CLEAR_REFERENCES=false:
#   "If true, Tomcat attempts to null out any static or final fields from loaded...around for apparent garbage collection bugs and application coding errors. There have been some issues reported with log4j when this option is true."

# CATALINA_OPTS and JAVA_OPTS are not forwarded for "java", but _JAVA_OPTIONS is
# MaxRAM does not hard limit - XmX higher than MaxRAM/3 seems to OOMKill
export _JAVA_OPTIONS="\
-XX:MaxRAM=${MEMORY_LIMIT_MAX} \
-XX:MaxRAMPercentage=${MAX_RAM_PERCENTAGE:-25} \
\
-Dfile.encoding=UTF8 \
-Duser.timezone=UTC \
-Duser.language=fi \
-Duser.region=FI \
-Djgroups.tcp.address=${INTERNAL_IP} \
-Dorg.apache.catalina.loader.WebappClassLoader.ENABLE_CLEAR_REFERENCES=false \
\
-XX:MetaspaceSize=384m \
-XX:MaxMetaspaceSize=384m \
\
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Dcom.sun.management.jmxremote.local.only=false \
-Dcom.sun.management.jmxremote.port=1099 \
-Dcom.sun.management.jmxremote.rmi.port=1099 \
-Djava.rmi.server.hostname=127.0.0.1 \

-XX:CompileThreshold=100 \
"

echo "java memory options:"
java -XX:+PrintFlagsFinal -version | grep -Ei "maxheapsize|maxram"

if [ "$DELETE_EVERYTHING" = "yes" ]; then
  echo "DELETE_EVERYTHING=yes"

  # if [ "$HOSTNAME" != "liferay-0" ]; then
  #   echo "TODO: maybe delete /app/osgi - but how, since liferay-0 does not become healthy for liferay-1, liferay-2 to deploy...?"
  #   echo "I'm not liferay-0, stopping here"
  #   tail -f /dev/null
  # fi

  export PGPASSWORD="$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD"

  set +e
    echo "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" | \
      psql -h "$DATABASE_HOST" -U "$LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME"
      echo "whole database cleared"

      rm -rf "/app/data/document_library/*"
      echo "deleted document_library"
  set -e

  set +e
    echo "FLUSHALL redis"
    echo "FLUSHALL" | redis-cli -h "$SESSION_REDIS_HOST" -p "$SESSION_REDIS_PORT"
  set -e

  echo "done"
  tail -f /dev/null
fi

echo "start: tomcat"

tomcat-9.0.10/bin/catalina.sh run &
tomcat_pid="$!"

if [ "$PRINT_MEMORY_USAGE_EVERY_N_SECONDS" != "" ]; then
  (
    while true; do
      set +e
        mem_stats=$(ps -eo pid,comm,rss | numfmt --header --from-unit=1024 --to=iec --field=3 | grep java | grep "$tomcat_pid" | awk '{print $NF}')
        echo "MEM: ${mem_stats}"

        sleep "${PRINT_MEMORY_USAGE_EVERY_N_SECONDS}"
      set -e
    done
  ) &
fi

while true; do
  kill -0 "$tomcat_pid" || break
  sleep 1
done

echo "tomcat is not alive, exit 1"
exit 1
