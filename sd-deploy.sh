#!/bin/bash -x

# Default Params
db_host="localhost"
db_port="3306"
db_name="ssc"
db_user="ssc"
db_pass="Password123"
sd_host=$(hostname -f)
sd_pub=$(ec2metadata --public-hostname 2>/dev/null)
sd_pub_ipv4=$(ec2metadata --public-ipv4)
sd_use_nat="YES"
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

# Start the daemon:
start ssc

# Setup the NAT (external_ip)
if [ "$sd_use_nat" == "YES" ]
then
    sleep 5
    curl -k -d "{\"external_ip\":\"${sd_pub_ipv4}\"}" -H "Content-Type: application/json" -u "${rest_user}:${rest_pass}" https://localhost:8100/api/tmcm/2.5/manager/${sd_host}
fi

