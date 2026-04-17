#!/bin/bash

help_string="""
Description:
    This script adds a new user to Dozzle. If a password is not provided, a random one will be generated.
    The encrypted user details are stored in ./config/.secret_users.yml.

Usage:
    $0 -u <user_name> -e <user_email> -n <user_fullname> [options]

Options:
    -u, --username        Username for the new Dozzle user (required).
    -e, --email           Email address for the new Dozzle user (required).
    -n, --fullname        Full name for the new Dozzle user. If not provided, it will capitalise the username and replace - or _ with spaces.
    -p, --password        Plain-text password for the new Dozzle user. If not provided, a random password will be generated.
    -v, --verbose         Show verbose output, which includes the *plain-text* password in the console. Use with caution.
    -s, --save_password   If set, the plain-text password will be saved to ./config/.secret_pass.yml along with the username.
    -h, --help            Show this help message

Examples:
    # Add a user with a random password and show the password in the console
        $0 -u newuser -e newuser@example.com -v
    # Add a user with a provided password and specified full name
        $0 -u newuser -e newuser@example.com -n 'New User' -p 'password123'
    # Add a user with a random password and save the password to ./config/.secret_pass.yml
        $0 -u newuser -e newuser@example.com -s
"""

# Default values
save_password="false"
verbose="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
        echo "$help_string"
        exit 0
        ;;
        -u|--username)
        [[ -n "$2" ]] || { echo "Error: --username requires a value."; exit 1; }
        user_name="$2"
        shift 2
        ;;
        -e|--email)
        [[ -n "$2" ]] || { echo "Error: --email requires a value."; exit 1; }
        user_email="$2"
        shift 2
        ;;
        -n|--fullname)
        [[ -n "$2" ]] || { echo "Error: --fullname requires a value."; exit 1; }
        provided_fullname="$2"
        shift 2
        ;;
        -p|--password)
        [[ -n "$2" ]] || { echo "Error: --password requires a value."; exit 1; }
        provided_password="$2"
        shift 2
        ;;
        -v|--verbose)
        verbose="true"
        shift
        ;;
        -s|--save_password)
        save_password="true"
        shift
        ;;
        *)
        echo "Unknown option: $1"
        echo "Use -h or --help for help"
        exit 1
        ;;
    esac
done

# Validate required arguments
if [ -z "$user_name" ] || [ -z "$user_email" ]; then
    echo "Error: Username and email are required."
    echo "$help_string"
    exit 1
fi
# If no password is provided and neither verbose nor save_password is set, exit with an error to avoid losing the generated password.
if [[ -z "$provided_password" && "$verbose" != "true" && "$save_password" != "true" ]]; then
    echo "No password provided. You must use either --verbose or --save_password to see the generated password."
    echo "Use -h or --help for help."
    exit 1
fi

# Move to the dozzle config directory (in case the script is run from a different location)
cd "$(dirname "$0")" || {
    echo "Error: Failed to change directory to script location."
    exit 1
}
mkdir -p ./config || {
    echo "Error: Failed to create config directory."
    exit 1
}
# Make sure user does not already exist
if [ -f ./config/.secret_users.yml ] && grep -q " ${user_name}:" ./config/.secret_users.yml; then
    echo "ERROR: User '$user_name' already exists."
    exit 1
fi

# Generate a random password if not provided
if [ -z "$provided_password" ]; then
    password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
else
    password="$provided_password"
fi
# Full name defaults to capitalized username if not provided (and replaces - or _ with spaces)
if [ -z "$provided_fullname" ]; then
    user_fullname=$(echo "$user_name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' | sed 's/-/ /g; s/_/ /g')
else
    user_fullname="$provided_fullname"
fi
# Generate the user block
user_block=$(docker run --rm amir20/dozzle generate "$user_name" --password "$password" --email "$user_email" --name "$user_fullname")
# Remove the "Generated user:" line from the output
user_block=$(echo "$user_block" | sed '1d')
# If file does not exist, create it with the users key
if [ ! -f ./config/.secret_users.yml ]; then
    echo "users:" > ./config/.secret_users.yml
fi
# Append the user block to the .secret_users.yml file
echo "$user_block" >> ./config/.secret_users.yml

# Save the plain-text password to .secret_pass.yml if requested
if [ "$save_password" = "true" ]; then
    echo "$user_name : $password" >> ./config/.secret_pass.yml
    echo "Plain-text password saved to ./config/.secret_pass.yml"
fi
# Print confirmation message
if [ "$verbose" = "true" ]; then
    echo "Adding the following user block to Dozzle:"
    echo "$user_block"
    if [ -z "$provided_password" ]; then
        echo "Generated password: $password"
    else
        echo "Provided password used."
    fi
else
    echo "User '$user_name' added to Dozzle."
fi
