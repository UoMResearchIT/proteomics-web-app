# This script configures rabbitmq username and password.
# To be able to subscribe and publish mqtt messsages after running this script, use for example:
#   mosquitto_sub -u "proteinBASE" -P "passwd" -t '#' -F "@Y-@m-@d @H:@M:@S %t %p"

#!/bin/bash

set -e

username=proteinBASE
password=$(cat .secret_passwd)

echo "Waiting for rabbitmqctl app..."
timeout=30
until $(docker exec pB-rabbitmq rabbitmqctl list_users > /dev/null 2>&1) || [ $timeout -eq 0 ]; do
    sleep 1
    timeout=$((timeout - 1))
    printf '.'
done
if [ $timeout -eq 0 ]; then
    echo "RabbitMQ container did not become ready within the expected time."
    exit 1
fi

docker exec pB-rabbitmq rabbitmqctl add_user $username $password
docker exec pB-rabbitmq rabbitmqctl set_user_tags $username administrator
docker exec pB-rabbitmq rabbitmqctl set_permissions -p / $username  ".*" ".*" ".*"
