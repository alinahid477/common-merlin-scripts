FROM debian:buster-slim


ENV DOCKER_VERSION=20.10.8

# culr (optional) for downloading/browsing stuff
# openssh-client (required) for creating ssh tunnel
# unzip needed 
RUN apt-get update && apt-get install -y \
	apt-transport-https \
	ca-certificates \
	openssh-client \
	curl \
	unzip \
	&& curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
	&& chmod +x /usr/local/bin/kubectl



RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  && tar xzvf docker-${DOCKER_VERSION}.tgz --strip 1 \
                 -C /usr/local/bin docker/docker \
  && rm docker-${DOCKER_VERSION}.tgz


COPY bastionhostinit.sh /usr/local/bastionhostinit.sh
RUN chmod +x /usr/local/bastionhostinit.sh


ENTRYPOINT [ "/usr/local/bastionhostinit.sh"]