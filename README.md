### Install basic dependencies

```sh
sudo apt-get update
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get -y install curl wget git postgis postgresql postgresql-contrib pgadmin3 zip nodejs nginx openjdk-8-jdk-headless

cd ~
git clone https://github.com/harshzalavadiya/naksha-docker-local
git clone https://github.com/strandls/naksha-docker
git clone https://github.com/strandls/naksha
git clone https://github.com/strandls/naksha-components-react
```

### Copy nginx configuration
```sh
sudo mv ~/naksha-docker-local/nginx.conf /etc/nginx/sites-enabled/default
```

### Create directories
```sh
sudo mkdir /apps
sudo chmod -R 777 /apps
```

### Building and Deploying Geoserver and Naksha to Tomcat
```sh
sh ~/naksha-docker-local/setup.sh
```

### Setting up front-end
install yarn https://yarnpkg.com/lang/en/docs/install/#debian-stable
```sh
cd ~/naksha-components-react
yarn install
yarn storybook
```