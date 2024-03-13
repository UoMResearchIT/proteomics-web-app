# Before running this script set the alias for the minio client:
#   mc alias set protein http://localhost:9000
#   Provide access keys from 'create' button at:
#   http://localhost:9001/access-keys
#
# If you are setting up for the first time, then run:
#   ./one_time_setup.sh -S

username=proteinBASE
password=$(cat .secret_passwd)
topics=("raw-data" "datasets" "heatmaps" "pcaplots" "dataset-info" "content")

usage() {
    echo "  Description:
    Setup or teardown minio services and buckets.
    Default behaviour is to setup services and buckets.

  Usage: 
    one_time_setup.sh [options]

  Options:
    -h, --help            Show this help message and exit.
    -S, --setup           Setup services and buckets.
    -T, --teardown        Teardown services and buckets.
    -ss, --set-services   Setup services.
    -sb, --set-buckets    Setup buckets.
    -ts, --tear-services  Teardown services.
    -tb, --tear-buckets   Delete buckets. If they are  not empty, this will fail unless --force is used.
    -f, --force           Force delete buckets. This will erase all the content both locally and remotely
    -v, --verbose         Show verbose output."
}

error() {
    echo "Error: $1"
    echo "Use -h or --help for help"
    exit 1
}

services="setup"
buckets="setup"
force="false"
verbose="false"

# Parse arguments
for arg in "$@"
do
    case $arg in
        -h|--help)
        usage
        exit 0
        ;;
        -S|--setup)
        services="setup"
        buckets="setup"
        ;;
        -T|--teardown)
        services="teardown"
        buckets="teardown"
        ;;
        -ss|--set-services)
        services="setup"
        ;;
        -sb|--set-buckets)
        buckets="setup"
        ;;
        -ts|--tear-services)
        services="teardown"
        ;;
        -tb|--tear-buckets)
        buckets="teardown"
        ;;
        -f|--force)
        force="true"
        ;;
        -v|--verbose)
        verbose="true"
        ;;
        *)
        error "Invalid argument: $arg"
        ;;
    esac
done

# Setup

if [ "$services" = "setup" ]; then
    if [ "$verbose" = "true" ]; then
        echo "Setting up services: ${topics[@]}"
        echo "Currently available:"
        # List the available mqtt services at the start of setup:
        mc admin config get protein notify_mqtt
    fi

    # Create events
    for topic in "${topics[@]}"
    do
        mc admin config set protein/ notify_mqtt:"$topic"  broker=tcp://rabbitmq:1883  topic=minio/"$topic"  username="$username"  password="$password"
    done

    # Restart minio to reflect changes
    mc admin service restart protein/

    if [ "$verbose" = "true" ]; then
        # List the available mqtt services at the end of setup:
        echo "Finished setting up services. Available now:"
        mc admin config get protein notify_mqtt
    fi
fi

if [ "$buckets" = "setup" ]; then
    if [ "$verbose" = "true" ]; then
        echo "Setting up buckets: ${topics[@]}"
        echo "Currently available:"
        # List the available buckets at the start of setup:
        mc ls protein
    fi

    # Create buckets and subscribe them to the events
    for topic in "${topics[@]}"
    do
        $(dirname "$0")/create_subscribe_bucket.sh --bucket_name="$topic" --endpoint="$topic" --test
    done

    if [ "$verbose" = "true" ]; then
        # List the available buckets at the end of setup:
        echo "Finished setting up buckets. Available now:"
        mc ls protein
    fi
fi

#Teardown

if [ "$services" = "teardown" ]; then
    if [ "$verbose" = "true" ]; then
        echo "Tearing down services:"
        # List the available mqtt services at the start of teardown:
        mc admin config get protein notify_mqtt
    fi

    # Delete the settings if things went wrong:
    for topic in "${topics[@]}"
    do
        mc admin config reset protein notify_mqtt:"$topic"
    done

    # Restart minio to reflect changes
    mc admin service restart protein/

    if [ "$verbose" = "true" ]; then
        # List the available mqtt services at the end of teardown:
        echo "Finished tearing down. Available services:"
        mc admin config get protein notify_mqtt
    fi
fi
if [ "$buckets" = "teardown" ]; then
    if [ "$verbose" = "true" ]; then
        echo "Tearing down buckets. Current buckets:"
        # List the available buckets at the start of teardown:
        mc ls protein
    fi

    # Delete the buckets
    for topic in "${topics[@]}"
    do
        if [ "$force" = "true" ]; then
            mc rb protein/"$topic" --force
        else
            mc rb protein/"$topic"
        fi
    done

    if [ "$verbose" = "true" ]; then
        # List the available buckets at the end of teardown:
        echo "Finished tearing down. Buckets remaining:"
        mc ls protein
    fi
fi