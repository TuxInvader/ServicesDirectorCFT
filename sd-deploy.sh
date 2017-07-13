#!/bin/bash

# Default Params
db_host=localhost
db_port=3306
db_name=ssc
db_user=ssc
db_pass=Password123
bsd_host=$(hostname)
bsd_port=8100
bsd_license_port=8101
alert_email=mbodding@brocade.com
alert_server=localhost
sources=/var/cache/ssc
logs=/var/logs/ssc
usercfg=/root/.sd-config.sh

# Load user configuration. Exit if they don't exist
if [ -f $usercfg ]
then
    source /root/.sd-config.sh
else
    echo "ERROR - No Configuration found" >&2
    exit 1
fi

certfile=${sources}/cert.pem
keyfile=${sources}/key.pem
mkdir -p $sources
mkdir -p $logs

# Check we have certificates
if [ -f "$certfile" or -n "$cert" ]
then
    if [ -n $cert ]
    then
        echo $cert > $certfile
    fi
else
    echo "ERROR - No Certificate found in config or on disk" >&2
    exit 1
fi

# Check we have keys
if [ -f "$keyfile" or -n "$key" ]
then
    if [ -n $key ]
    then
        echo $key > $certfile
    fi
else
    echo "ERROR - No Private Key found in config or on disk" >&2
    exit 1
fi

cat <<-EOF | debconf-set-selections
    riverbed_ssc ssc/db/host string $db_host
    riverbed_ssc ssc/db/port string $db_port
    riverbed_ssc ssc/db/name string $db_name
    riverbed_ssc ssc/db/user string $db_user
    riverbed_ssc ssc/db/password password $db_pass
    riverbed_ssc ssc/server/name string $bsd_host
    riverbed_ssc ssc/server/port string $bsd_port
    riverbed_ssc ssc/server/license_port string $bsd_license_port
    riverbed_ssc ssc/server/cert_file string $certfile
    riverbed_ssc ssc/server/key_file string $keyfile
    riverbed_ssc ssc/server/numthreads string 20
    riverbed_ssc ssc/server/actionthreads string 5
    riverbed_ssc ssc/server/monitorthreads string 20
    riverbed_ssc ssc/server/meteringthreads string 20
    riverbed_ssc ssc/files/sources string $sources
    riverbed_ssc ssc/files/logs string $logs
    riverbed_ssc ssc/alerts/address string $alert_email
    riverbed_ssc ssc/alerts/smtp_host string $alert_server
    riverbed_ssc ssc/alerts/smtp_port string 25
EOF


