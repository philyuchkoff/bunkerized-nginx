#!/bin/bash

. /usr/share/bunkerweb/helpers/utils.sh

log "ENTRYPOINT" "ℹ️" "Starting BunkerWeb v$(cat /usr/share/bunkerweb/VERSION) ..."

# setup and check /data folder
/usr/share/bunkerweb/helpers/data.sh "ENTRYPOINT"

# trap SIGTERM and SIGINT
function trap_exit() {
	log "ENTRYPOINT" "ℹ️" "Catched stop operation"
	log "ENTRYPOINT" "ℹ️" "Stopping nginx ..."
	nginx -s stop
}
trap "trap_exit" TERM INT QUIT

# trap SIGHUP
function trap_reload() {
	log "ENTRYPOINT" "ℹ️" "Catched reload operation"
	if [ -f /var/tmp/bunkerweb/nginx.pid ] ; then
		log "ENTRYPOINT" "ℹ️" "Reloading nginx ..."
		nginx -s reload
		if [ $? -eq 0 ] ; then
			log "ENTRYPOINT" "ℹ️" "Reload successful"
		else
			log "ENTRYPOINT" "❌" "Reload failed"
		fi
	else
		log "ENTRYPOINT" "⚠️" "Ignored reload operation because nginx is not running"
	fi
}
trap "trap_reload" HUP

if [ "$SWARM_MODE" == "yes" ] ; then
	echo "Swarm" > /usr/share/bunkerweb/INTEGRATION
elif [ "$KUBERNETES_MODE" == "yes" ] ; then
	echo "Kubernetes" > /usr/share/bunkerweb/INTEGRATION
elif [ "$AUTOCONF_MODE" == "yes" ] ; then
	echo "Autoconf" > /usr/share/bunkerweb/INTEGRATION
fi

if [ -f "/etc/nginx/variables.env" ] ; then
	log "ENTRYPOINT" "⚠️ " "Looks like BunkerWeb has already been loaded, will not generate temp config"
else
	# generate "temp" config
	echo -e "IS_LOADING=yes\nSERVER_NAME=\nAPI_HTTP_PORT=${API_HTTP_PORT:-5000}\nAPI_SERVER_NAME=${API_SERVER_NAME:-bwapi}\nAPI_WHITELIST_IP=${API_WHITELIST_IP:-127.0.0.0/8}" > /tmp/variables.env
	python3 /usr/share/bunkerweb/gen/main.py --variables /tmp/variables.env
fi

# start nginx
log "ENTRYPOINT" "ℹ️" "Starting nginx ..."
nginx -g "daemon off;" &
pid="$!"

# wait while nginx is running
wait "$pid"
while [ -f "/var/tmp/bunkerweb/nginx.pid" ] ; do
	wait "$pid"
done

log "ENTRYPOINT" "ℹ️" "BunkerWeb stopped"
exit 0