#!/usr/bin/env bash
echo ">>> Loading environment variables from /vagrant/.env"
sed -i '/\015/d' /vagrant/.env
sed -i '/\015/d' /vagrant/.bashrc
set -a
. /vagrant/.env
. /vagrant/.bashrc
set +a


if [[ ! -f ${CUSTOM_PROFILE_FILENAME} ]]; then
  echo ">>> Adding the environment variables and functions to /etc/profile, making them persistent"
  echo "set -a" > /etc/profile.d/${CUSTOM_PROFILE_FILENAME}
  echo "source /vagrant/.env" >> /etc/profile.d/${CUSTOM_PROFILE_FILENAME}
  echo "source /vagrant/.bashrc" >> /etc/profile.d/${CUSTOM_PROFILE_FILENAME}
  echo "set +a" >> /etc/profile.d/${CUSTOM_PROFILE_FILENAME}
fi


# This is required by Elastic Search, otherwise it will crash, as described here:
# https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
if [[ "$(sysctl -n vm.max_map_count)" -ne "$ES_MAX_MAP_COUNT" ]]; then
  echo ">>> Setting the maximum number of memory map areas a process may have to ${ES_MAX_MAP_COUNT}"
  sysctl -w vm.max_map_count=${ES_MAX_MAP_COUNT}

  # Make vm.max_map_count setting permanent
  if [[ ! -f ${ES_SYSCTL_CONF_FILE} ]]; then
    echo "  > Making the MAX_MAP_COUNT setting for Elastic Search persistent"
    echo "vm.max_map_count=$ES_MAX_MAP_COUNT" | tee -a ${ES_SYSCTL_CONF_FILE}
  fi
fi


if ! ( command -v docker ); then
  echo ">>> Cleaning up Yum's cache"
  yum clean all
  rm -rf /var/cache/yum/*

  echo ">>> Installing Docker"
  yum install -y   yum-utils   device-mapper-persistent-data   lvm2
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
fi


if ! ( grep -q -E "^docker:" /etc/group ); then
  echo ">>> Creating a docker user group"
  groupadd docker
fi


if ! groups vagrant | grep -qw docker; then
    echo "  > Adding 'vagrant' user to the docker group"
    usermod -a -G docker vagrant
fi


if ! ( systemctl list-unit-files --state=enabled | grep -q -E "^docker.service" ); then
  echo ">>> Setting up docker daemon to start automatically"
  systemctl enable docker
fi


if ! ( systemctl is-active --quiet docker ); then
  echo ">>> Starting docker daemon"
  systemctl start docker
fi


if [[ ! -f ${DOCKER_COMPOSE_LOCATION} ]]; then
  echo ">>> Downloading docker-compose and making it executable"
  curl -L "$DOCKER_COMPOSE_BASE_URL/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
            -o "$DOCKER_COMPOSE_LOCATION"
  chmod +x "$DOCKER_COMPOSE_LOCATION"
fi


if [[ -z `docker ps -q --no-trunc | grep $(${DOCKER_COMPOSE_LOCATION} -f /vagrant/docker-compose.yml --project-directory /vagrant ps -q web)` ]]; then
  echo ">>> Setting up the MMS services"
  setup
fi
