usage() {
    echo "  Description: 
    Create a bucket and subscribe it to an endpoint.
    If test is enabled, a temp file will be copied and deleted from the bucket.

  Usage:
    create_subsribe_bucket.sh --name=<bucket_name> --endpoint=<endpoint> [--test]

  Options:
    -h, --help  Show this help message and exit.
    -n, --name=<bucket_name>  Name of the bucket to create.
    -e, --endpoint=<endpoint>  Endpoint to subscribe to.
    -v  --verbose  Show verbose output.
    -t, --test  Test the subscription by copying and deleting a file from the bucket."
}

error() {
    echo "Error: $1"
    echo "Use -h or --help for help"
    exit 1
}

verbose="false"

# Parse arguments
for arg in "$@"
do
    case $arg in
        -h|--help)
        usage
        exit 0
        ;;
        -n=*|--name=*|--bucket_name=*)
        bucket_name="${arg#*=}"
        ;;
        -e=*|--endpoint=*)
        endpoint="${arg#*=}"
        ;;
        -v|--verbose)
        verbose="true"
        ;;
        -t|--test)
        test=1
        ;;
        *)
        error "Invalid argument: $arg"
        ;;
    esac
done

if [ -z "$bucket_name" ]; then
    error "Bucket name is required"
fi
if [ -z "$endpoint" ]; then
    error "Endpoint is required"
fi
if [ -z "$test" ]; then
    test=0
fi




# Create bucket
mc mb protein/"$bucket_name" --with-versioning

# Make bucket publsih on events (subscribe bucket to events)
mc event add protein/"$bucket_name" arn:minio:sqs::"$endpoint":mqtt --event "put,get,delete,replica,ilm,scanner"

if [ "$verbose" = "true" ]; then
    # List events
    mc event list protein/"$bucket_name"
fi

# Test messages are sent on copy and delete
if [ "$test" -ne 0 ]; then
    # Echo random string to temp file
    tr -cd '[:alnum:]' < /dev/urandom | fold -w "64" | head -n 1 > /tmp/1.txt
    # Copy file to bucket
    mc cp /tmp/1.txt protein/"$bucket_name"
    if [ "$verbose" = "true" ]; then
        # List files in bucket
        mc ls protein/"$bucket_name"
    fi
    # Remove file from bucket
    mc rm protein/"$bucket_name"/1.txt --versions --force
fi
