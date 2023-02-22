FROM ubuntu:20.04 AS base

RUN apt update \
    && apt install -y ca-certificates openssh-client \
    wget curl iptables supervisor \
    && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL=stable \
	#DOCKER_VERSION=20.10.22 \
	#DOCKER_COMPOSE_VERSION=1.29.2 \
	DOCKER_VERSION=23.0.0 \
	DOCKER_COMPOSE_VERSION=2.16.0 \
	DEBUG=false

# Docker installation
RUN set -eux; \
	\
	arch="$(uname --m)"; \
	case "$arch" in \
        # amd64
		x86_64) dockerArch='x86_64' ;; \
        # arm32v6
		armhf) dockerArch='armel' ;; \
        # arm32v7
		armv7) dockerArch='armhf' ;; \
        # arm64v8
		aarch64) dockerArch='aarch64' ;; \
		*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
	esac; \
	\
	if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
		exit 1; \
	fi; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	dockerd --version; \
	docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker

# Docker compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
	&& chmod +x /usr/local/bin/docker-compose && docker-compose version

# adding nonroot user
RUN adduser nonroot && \
	groupadd docker && \
	usermod -aG docker nonroot

FROM base AS dependencies

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && apt-get -y install gpg && \
	curl -fsSL https://apt.fury.io/drud/gpg.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/ddev.gpg > /dev/null && \
	echo "deb [signed-by=/etc/apt/trusted.gpg.d/ddev.gpg] https://apt.fury.io/drud/ * *" | tee /etc/apt/sources.list.d/ddev.list && \
	apt update && apt install -y ddev

RUN apt update && apt-get -y install php && \
	apt-get install -y php-curl && \
	apt-get install -y php-xml && \
	mkdir /usr/src/composer && \
	cd /usr/src/composer && \
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
	php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
	php composer-setup.php && \
	php -r "unlink('composer-setup.php');" && \
	mv composer.phar /usr/local/bin/composer 

FROM dependencies AS webserver

COPY ddev-startup.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/ddev-startup.sh

RUN mkdir /usr/src/project && \
	chown nonroot /usr/src/project

WORKDIR /usr/src/project

ENTRYPOINT ["startup.sh"]
CMD ["bash"]
