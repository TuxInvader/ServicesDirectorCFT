#!/bin/bash -x

# Default Params
db_host="localhost"
db_port="3306"
db_name="ssc"
db_user="ssc"
db_pass="Password123"
sd_host=$(hostname -f)
sd_pub=$(ec2metadata --public-hostname 2>/dev/null)
sd_instance_id=$(ec2metadata --instance-id)
sd_pub_ipv4=$(ec2metadata --public-ipv4)
sd_use_nat="YES"
sd_remove_managers="YES"
sd_vers="17.2"
sd_port="8100"
sd_license_port="8101"
alert_email="root@localhost"
alert_server="localhost"
sources="/var/cache/ssc"
logs="/var/log/ssc"
usercfg="/root/.sd-config.sh"

# cfn signal
finished() {
    /usr/local/bin/cfn-signal -s $1 -r "$2" "$3"
}

# Drop license files into the licenses folder add_licenses <SDVers> <csv>
add_licenses() {
    lics=( $( echo $2 | sed -e's/,/ /g') )
    for (( i=0; i<${#lics[@]} ; i++ ))
    do
        echo "${lics[i]}" > /opt/riverbed_ssc_$1/licenses/lic_${i}.txt
    done
}

# setup for local mysql
setup_mysql() {
    echo "mysql-server-5.6 mysql-server/root_password password $1" | debconf-set-selections
    echo "mysql-server-5.6 mysql-server/root_password_again password $1" | debconf-set-selections
    echo -e "[mysqld]\nquery_cache_type=1\n" > /etc/mysql/conf.d/ssc.cnf
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server-5.6
    mysql -uroot -p${sd_enc_key} -e "use $db_name"
    if [ $? != 0 ]
    then
        mysql -uroot -p${sd_enc_key} -e "create database $db_name"
        mysql -uroot -p${sd_enc_key} -e "grant all on ssc.* to $db_user@'localhost' identified by '$db_pass'"
        mysql -uroot -p${sd_enc_key} -e "flush privileges"
    fi
}

# setup for local email
setup_postfix() {
    sd_host=$1
    sd_pub=$2
    echo "postfix postfix/destinations string  $sd_host, $sd_pub, localhost" | debconf-set-selections
    echo "postfix postfix/mailname    string  $sd_pub" | debconf-set-selections
    echo "postfix postfix/main_mailer_type    select  Internet Site" | debconf-set-selections
    echo "postfix postfix/protocols   select  all" | debconf-set-selections
    echo "postfix postfix/recipient_delim string  +" | debconf-set-selections
    echo "postfix postfix/mailbox_limit   string  0" | debconf-set-selections
    echo "postfix postfix/procmail    boolean false" | debconf-set-selections
    echo "postfix postfix/chattr  boolean false" | debconf-set-selections
    echo "postfix postfix/rfc1035_violation   boolean false" | debconf-set-selections
    echo "postfix postfix/mynetworks  string  127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
    echo "canonical_maps = hash:/etc/postfix/sender.alias" >> /etc/postfix/main.cf
    echo "root  root@$sd_pub" > /etc/postfix/sender.alias
    postmap hash:/etc/postfix/sender.alias
    /etc/init.d/postfix reload
}

# setup the persistent storage
setup_storage() {
    logs=$1
    sources=$2
    if [ ! -b /dev/xvdb1 ]
    then
        echo '0,,L' | sfdisk /dev/xvdb
        mkfs.ext4 /dev/xvdb1
    fi
    mkdir /data
    mount /dev/xvdb1 /data
    if [ $? != 0 ]
    then
        finished false "ERROR - Persistent Storage Mount Failed" $wait_handle
        exit 1
    fi
    mkdir -p /data/ssc/logs
    mkdir -p /data/ssc/cache
    mkdir -p /data/mysql
    mkdir -p /var/lib/mysql
    mkdir -p $logs
    mkdir -p $sources
    mount -o bind /data/ssc/logs $logs
    mount -o bind /data/ssc/cache $sources
    mount -o bind /data/mysql /var/lib/mysql
}

remove_old_managers() {
    rest_user=$1
    rest_pass=$2
    sd_host=$3
    for manager in $(curl -s -k -u "${rest_user}:${rest_pass}" https://localhost:8100/api/tmcm/2.5/manager | jq '.children' | jq -c ".[] | select(.name != \"${sd_host}\") | .href" | sed -e's/"//g')
    do 
        curl -s -k -u "${rest_user}:${rest_pass}" -X delete "https://localhost:8100${manager}"
    done
}

# Load user configuration. Exit if they don't exist
if [ -f $usercfg ]
then
    source /root/.sd-config.sh
else
    finished false "ERROR - No Configuration found" $wait_handle
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
    finished false "ERROR - No Certificate found in config or on disk" $wait_handle
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
    finished false "ERROR - No Private Key found in config or on disk" $wait_handle
    exit 1
fi

# Check for persistent storage.
if [ -n "$data_volume" ]
then
    aws ec2 attach-volume --volume-id $data_volume --instance-id $sd_instance_id --device xvdb
    if [ $? == 0 ]
    then
        sleep 5
        setup_storage $logs $sources
    else
        finished false "ERROR - Persistent Storage Attach Failed" $wait_handle
        exit 1
    fi
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

# Add your Services Controller license file(s)
add_licenses "$sd_vers" "$licenses"

# Set up your database:
if [ "$db_host" == "localhost" ]
then
    setup_mysql "$sd_enc_key"
fi

# Set up your email:
if [ "$alert_server" == "localhost" ]
then
    setup_postfix "$sd_host" "$sd_pub"
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
    expect {
        encryption: {
            send "$sd_enc_key\n" 
            expect {
                password: {
                    send "$sd_enc_key\n"
                    expect :
                    send "y\n"
                }
                encryption: {
                    send_user "\nERROR - Password too weak!\n"
                    exit 1
                }
            }
            exp_continue
        }
        Checking {
            exp_continue
        }
        Operations {
            exp_continue
        }
        Running {
            exp_continue
        }
        Applying {
            exp_continue
        }
        problem {
            send_user "\nERROR - Failed to setup database!\n"
            exit 1
        }
        completed {
            send_user "\nLive Config Complete!\n"
            sleep 5
            exit 0
        }
    }
EOF
[ $? != 0 ] && finished false "SSC Live-Config Failed" $wait_handle

# Provide the master password, the liveconfig doesn't ask if the DB exists.
master="/opt/riverbed_ssc_${sd_vers}/etc/master"
[ ! -f $master ] && echo -n "1:${sd_enc_key}" > $master

# Start the daemon:
start ssc
sleep 5

# Setup the NAT (external_ip)
if [ "$sd_use_nat" == "YES" ]
then
    curl -k -d "{\"external_ip\":\"${sd_pub_ipv4}\"}" -H "Content-Type: application/json" -u "${rest_user}:${rest_pass}" https://localhost:8100/api/tmcm/2.5/manager/${sd_host}
fi

# Remove previous SD instances from managers table
if [ "$sd_remove_managers" == "YES" ]
then
    remove_old_managers "$rest_user" "$rest_pass" "$sd_host"
fi

finished true "Complete" $wait_handle

