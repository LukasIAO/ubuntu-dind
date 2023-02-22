#!/bin/bash

echo "Starting ddev instance..."
#chown -R nonroot /usr/src/project
#chmod -R 744 /usr/src/project 

cd /usr/src/project

# forwards ports if not already configured
if grep -m 1 -Fxq "bind_all_interfaces: false" /usr/src/project/.ddev/config.yaml; then
    su nonroot -c 'ddev config --host-webserver-port=8080 --bind-all-interfaces $nonroot'
    chown -R nonroot .ddev
fi

# runs composer installer on first boot
if ! test -f "/usr/src/project/var/DEPENDENCIES_INSTALLED.txt"; then
    echo "Updating project dependencies..."
    composer update
    composer install
    chmod 777 -R /usr/src/project/var/cache
    touch /usr/src/project/var/DEPENDENCIES_INSTALLED.txt
fi

echo "Serving webpage..."
su nonroot -c 'yes | ddev start $nonroot'

cd db

if ! test -f "db.sql"; then
    gunzip db.sql.gz
fi

su nonroot -c 'ddev import-db < db.sql $nonroot'