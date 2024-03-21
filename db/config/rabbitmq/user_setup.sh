# This script configures rabbitmq username and password.
# To be able to subscribe and publish mqtt messsages after running this script, use for example:
#   mosquitto_sub -u "proteinBASE" -P "passwd" -t '#' -F "@Y-@m-@d @H:@M:@S %t %p"

#!/bin/bash

set -e

username=proteinBASE
password=$(cat .secret_passwd)

docker exec pB-rabbitmq rabbitmqctl add_user $username $password
docker exec pB-rabbitmq rabbitmqctl set_user_tags $username administrator
docker exec pB-rabbitmq rabbitmqctl set_permissions -p / $username  ".*" ".*" ".*"
