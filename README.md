# proteinBASE

The proteinBASE site has two parts:
 - The app: This has public access, and displays datasets and pre-configured plots.
 This is a shiny-app, and it is contained in the `app` directory (except for the data).

 - The database: Restricted access to admin users.
 The front end is managed by minio, and serves as a portal to upload the datasets.
 Uploading a raw dataset triggers a workflow for pre-processing the data.
 Once the data is pre-processed, it is copied to the website's database, and becomes available to users.

## Deploying the shiny app
The service is orquestrated using docker-compose, so the server must have a working installation of docker.

### Clone this repository
You will need git installed to clone this repo.
```
sudo apt update
sudo apt upgrade -y
sudo apt install -y git
git clone https://github.com/UoMResearchIT/proteomics-web-app.git proteinBASE
```

### Installing docker
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

### One time setup
Navigate to the cloned repo directory, and setup minio for the first time:
```
cd proteinBASE
docker compose up minio proxy -d
```
#### Minio keys
On a browser, use the url of the machine serving the site to configure the minio keys.
For example, if the ip is 10.20.30.40, in a browser go to
```
http://10.20.30.40:9001/access-keys
```
Log in using the temporary credentials
```
u: ROOTUSER
p: CHANGEME123
```
Update your credentials.
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

#### Proxy setting
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
Traffic should now be forwarded to the right frontentd for each domain.

### SSL certificates