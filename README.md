# proteinBASE

The proteinBASE site has two parts:
 - The app: This has public access, and displays datasets and pre-configured plots.
 This is a shiny-app, and it is contained in the `app` directory (except for the data).

 - The database: Restricted access to admin users.
 The front end is managed by minio, and serves as a portal to upload the datasets.
 Uploading a raw dataset triggers a workflow for pre-processing the data.
 Once the data is pre-processed, it is copied to the website's database, and becomes available to users.

## Table of Contents
- [proteinBASE](#proteinbase)
    - [Table of Contents](#table-of-contents)
    - [Adding a new dataset](#adding-a-new-dataset)
    - [Adding dataset information](#adding-dataset-information)
    - [Deleting a dataset](#deleting-a-dataset)
    - [Editing the app content pages](#editing-the-app-content-pages)
    - [Deploying the shiny app](#deploying-the-shiny-app)
        - [Clone this repository](#clone-this-repository)
        - [Installing docker](#installing-docker)
        - [One time setup](#one-time-setup)
            - [Minio keys](#minio-keys)
            - [Dozzle users](#dozzle-users)
            - [Proxy setting](#proxy-setting)
            - [SSL certificates](#ssl-certificates)
    - [Debugging](#debugging)
        - [Dozzle](#dozzle)
        - [Debugging through ssh](#debugging-through-ssh)
            - [Logs](#logs)
            - [Docker exec](#docker-exec)

## Adding a new dataset
New datasets, need to be uploaded to the raw-datasets directory in the minio server.

For this, you need to have a user and a password.

 - On the side menu, make sure you are on the **object browser** tab.
 - Select he "**raw-data**" bucket.
 - On the top right, click on the "**Upload**" button and select "**Upload File**".
 - Select the file you want to upload, and confirm.

Once the raw data file is uploaded, the server will start pre-processing the data, and upload the processed data to the *datasets*, *heatmaps*, and *pcaplots* buckets.

When these files have been added, you can refresh the app's page, and you should see the dataset in the list of available datasets.

## Adding dataset information

The dataset information tab renders .md files in the "**dataset-info**" bucket.

To upload or edit the information, make sure the name of the file matches the name of the dataset, and that it ends with "_info.md".

For example, if the dataset is called "my_dataset", the file should be called "my_dataset_info.md".

## Deleting a dataset

If you want to completely remove a dataset and all of its related files (in the datasets, heatmaps, pcaplots, and dataset-info buckets), you can do so by deleting the file in the raw-data bucket.

If you remove the file from the datasets bucket, the related files will not be deleted, but wont be available in the app.

## Editing the app content pages

The app content pages are written in markdown, and are stored in the *content* bucket.
Use the same procedure as for the dataset information files to edit the content pages.

# Deploying the shiny app
The service is orquestrated using docker-compose, so the server must have a working installation of docker.

## Clone this repository
You will need git installed to clone this repo.
```
sudo apt update
sudo apt upgrade -y
sudo apt install -y git
git clone https://github.com/UoMResearchIT/proteomics-web-app.git proteinBASE
```

## Installing docker
On an ubuntu system, you can install docker and docker compose using this [convinience script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script), in summary, run:
```
sudo apt update
sudo apt upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
rm get-docker.sh
```
Test docker is installed by running:
```
docker run hello-world
```
At this point, you can also download the docker images needed for deployment:
```
docker pull  ghcr.io/uomresearchit/pb-rclient:latest
docker pull ghcr.io/uomresearchit/pb-shinyapp:latest
docker pull docker.io/bitnami/rabbitmq:3.12
docker pull quay.io/minio/minio:latest
docker pull jc21/nginx-proxy-manager:latest
```

## One time setup
Navigate to the cloned repo directory.
```
cd proteinBASE
```
Create a password for the root user of minio. You can generate a random one with:
```
echo "MINIO_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)" > ./db/config/minio/.secret_minio_passwd
```
Now we can spin up minio for the first time:
```
docker compose up minio proxy -d
```
### Minio keys
On a browser, use the url of the machine serving the site to configure the minio keys.
For example, if the ip is 10.20.30.40, in a browser go to
```
http://10.20.30.40:9001/access-keys
```
Log in using the root user credentials ( user: ROOTUSER and the password you just generated).

Once logged in, use the 'create' button.
Hit 'Create' again, and then 'Download for import'.

Copy the downloaded file to the server, for example using scp, as `.secret_credentials.json` in `db/config/minio/`
```
scp ~/Downloads/credentials.json user@10.20.30.40:~/proteinBASE/db/config/minio/.secret_credentials.json
```

Once the keys are in the right place, you can use the bootstrap script:
```
./db/config/bootstrap.sh
```
### Dozzle users
User credentials for the dozzle service are configured in `./dozzle/config/.secret_users.yml`.

To generate new users, you may use the `add_dozzle_user.sh` script:
```
./dozzle/add_dozzle_user.sh -u 'user_name' -e 'user@email.com' -n 'Full User Name' -v
```

This will generate a new user with the specified name, email, and full name.
It will also generate a random password and print it to the console.

**Note:** Make sure to take note of the password, as it will not be shown again.
Alternatively, you can provide a password with the `-p` option, or save the generated password to a file with the `-s` option.

### Proxy setting
On a browser, use the url of the machine serving the site to configure the proxy.
For example, if the ip is 10.20.30.40, in a browser go to
```
http://ip_address_here:81
```
Log in using the temporary credentials
```
u: admin@example.com
p: changeme
```
Update your credentials.
On the menu, click on Hosts -> Proxy Hosts, and then click on  "Add Proxy Host".
Fill in the details for each domain:
```
Name: proteinBASE.manchester.ac.uk
Forward Hostname: pB-shinyapp
Forward Port: 5678
Websockets Support: On
```
```
Name: upload.proteinBASE.manchester.ac.uk
Forward Hostname: pB-minio
Forward Port: 9001
Websockets Support: On
```
Traffic should now be forwarded to the right frontend for each domain.

### SSL certificates
Load the ssl certificates in the "SSL Certificates" section of the proxy manager.
Then, select the corresponding certificate for each domain in the proxy host settings.

# Debugging

## Dozzle
The dozzle service provides a web interface to view the logs of all the other services in the compose stack.
To access it, go to the url of the machine serving the site, on port 8080. For example:
```
http://10.20.30.40:8080
```
Log in with the credentials you set up in the previous steps, and you should be able to see the logs of all the services in real time.

The dozzle service is configured for log viewing only, so you cannot interact with the containers.

## Debugging through ssh
If you have ssh access to the server, you can also debug the services through the command line.

### Logs
An important access point for debugging the site is the docker compose logs.

You can access all of the logs together with:
```
docker compose logs -f
```
where the -f option follows the logs live.

Alternatively, you can look at the logs of each service (or a selected group) with
```
docker compose logs -f <service name>
```
The services are as follows:

- **shinyapp**: The shiny app, serving the public site.
- **minio**: The minio service, serving the front end for the database.
- **rclient**: An mqtt client, listening for events in the minio site, in charge of the data pre-processing workflow.
- **rabbitmq**: The message broker used to connect the minio and rclient services.
- **proxy**: The nginx proxy manager, in charge of the domain routing.

### Docker exec

Another useful tool for debugging is the docker exec command, which allows you to jump inside of one of the running containers.

For example, to jump inside the shinyapp container, you can run:
```
docker exec -it pb-shinyapp bash
```
This will open a bash shell inside the container, where you can run commands to debug the app.
