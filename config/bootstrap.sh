# This script should bootstrap the backend for data storage and pre-processing
# It generates a random password for the mqtt broker, launches the docker compose
# network, and finalises configuration of the broker and minio buckets.
#
# It should only be run once! If it fails, cherry pick the commands you need.

#!/bin/bash

# Do not continue on error
set -e
# Change the current directory to the directory of the script
cd "$(dirname "$0")"
# Generate random password
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1 > .secret_passwd
# Launch docker compose newtork
cd ../
docker compose up -d
# Wait for RabbitMQ to be ready
echo "Waiting for rabbitmq service..."
timeout=60
until $(curl --output /dev/null --silent --head --fail http://localhost:15672) || [ $timeout -eq 0 ]; do
    sleep 1
    timeout=$((timeout - 1))
    printf '.'
done
if [ $timeout -eq 0 ]; then
    echo "RabbitMQ service did not become ready within the expected time."
    exit 1
fi
echo "."
sleep 2
cd config
# Configure rabbitmq username and password
./rabbitmq/user_setup.sh
# Configure minio buckets
./minio/one_time_setup.sh -S


# To undo the important steps in the script do:
# Teardown minio buckets
#   ./minio/one_time_setup.sh -T
# Teardown docker compose network and forget rabbit configuration
#   docker compose down -v
