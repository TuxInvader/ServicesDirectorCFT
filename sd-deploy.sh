#!/bin/bash -x

# Default Params
db_host="localhost"
db_port="3306"
db_name="ssc"
db_user="ssc"
db_pass="Password123"
sd_host=$(hostname -f)
sd_vers="17.2"
sd_port="8100"
sd_license_port="8101"
alert_email="root@localhost"
alert_server="localhost"
sources="/var/cache/ssc"
logs="/var/log/ssc"
usercfg="/root/.sd-config.sh"

# Drop license files into the licenses folder add_licenses <SDVers> <csv>
add_licenses() {
    IFS=, lics=( $2 )
    for (( i=0; i<${#lics[@]} ; i++ ))
    do
        echo "${lics[i]}" > /opt/riverbed_ssc_$1/licenses/lic_${i}.txt
    done
}

# setup for local mysql
setup_mysql() {
    echo "mysql-server-5.6 mysql-server/root_password password $1" | debconf-set-selections
    echo "mysql-server-5.6 mysql-server/root_password_again password $1" | debconf-set-selections
    apt-get install -y mysql-server-5.6
    echo -e "[mysqld]\nquery_cache_type=1\n" > /etc/mysql/conf.d/ssc.cnf
    stop mysql-server
    start mysql-server
    mysql -uroot -p${sd_enc_key} -e "use $db_name"
    if [ $? != 0 ]
    then
        mysql -uroot -p${sd_enc_key} -e "create database $db_name"
        mysql -uroot -p${sd_enc_key} -e "grant all on ssc.* to $db_user@'localhost' identified by '$db_pass'"
        mysql -uroot -p${sd_enc_key} -e "flush privileges"
    fi
}

# Load user configuration. Exit if they don't exist
if [ -f $usercfg ]
then
    source /root/.sd-config.sh
else
    echo "ERROR - No Configuration found" >&2
    exit 1
fi

certfile=/etc/ssl/certs/ssc-cert.pem
keyfile=/etc/ssl/private/ssc-key.pem

# Check we have certificates
if [ -f "$certfile" -o -n "$cert" ]
then
    if [ -n "$cert" ]
    then
        echo -e "$cert" > $certfile
    fi
else
    echo "ERROR - No Certificate found in config or on disk" >&2
    exit 1
fi

# Check we have keys
if [ -f "$keyfile" -o -n "$key" ]
then
    if [ -n "$key" ]
    then
        echo -e "$key" > $keyfile
    fi
else
    echo "ERROR - No Private Key found in config or on disk" >&2
    exit 1
fi

cat <<-EOF | debconf-set-selections
    riverbed-ssc ssc/db/host string $db_host
    riverbed-ssc ssc/db/port string $db_port
    riverbed-ssc ssc/db/name string $db_name
    riverbed-ssc ssc/db/user string $db_user
    riverbed-ssc ssc/db/password password $db_pass
    riverbed-ssc ssc/server/name string $sd_host
    riverbed-ssc ssc/server/port string $sd_port
    riverbed-ssc ssc/server/license_port string $sd_license_port
    riverbed-ssc ssc/server/cert_file string $certfile
    riverbed-ssc ssc/server/key_file string $keyfile
    riverbed-ssc ssc/server/numthreads string 20
    riverbed-ssc ssc/server/actionthreads string 5
    riverbed-ssc ssc/server/monitorthreads string 20
    riverbed-ssc ssc/server/meteringthreads string 20
    riverbed-ssc ssc/files/sources string $sources
    riverbed-ssc ssc/files/logs string $logs
    riverbed-ssc ssc/alerts/address string $alert_email
    riverbed-ssc ssc/alerts/smtp_host string $alert_server
    riverbed-ssc ssc/alerts/smtp_port string 25
EOF

DEBIAN_FRONTEND=noninteractive dpkg -i /root/sd-package.deb

# * Add your Services Controller license file(s)
add_licenses "$sd_vers" "$licenses"

# * Set up your database:
if [ "$db_host" == "localhost" ]
then
    setup_mysql $sd_enc_key
fi

# Run live config
cat <<EOF | expect
    spawn /opt/riverbed_ssc_17.2/bin/configure_ssc --liveconfigonly
    expect user:
    send "$rest_user\n"
    expect user:
    send "$rest_pass\n"
    expect password:
    send "$rest_pass\n"
    expect encryption:
    send "$sd_enc_key\n"
    expect {
        password: {
            send "$sd_enc_key\n"
        }
        encryption: {
            send_user "\n\nERROR - Password too weak!\n"
            exit 1
        }
    }
    expect :
    send "y\n"
    expect eof
    sleep 2
EOF

# * Start the daemon:
#start ssc



