# After Travis CI adjusts their plan, we don't have enough free credit to run the build. So daily build has been adjusted to weekly. If you don't get latest version, please wait for one week.

# socat

Run socat command in alpine container

[![DockerHub Badge](http://dockeri.co/image/alpine/socat)](https://hub.docker.com/r/alpine/socat/)

Auto-trigger docker build for [socat](https://pkgs.alpinelinux.org/package/edge/main/x86/socat) when new version is released.

### Repo:

https://github.com/alpine-docker/socat

### Daily build logs:

https://travis-ci.com/alpine-docker/socat

### Docker image tags:

https://hub.docker.com/r/alpine/socat/tags/

## Use Case: Expose a tcp socket for accessing docker API on macOS

The Docker for Mac native macOS application provides use of docker engine without the need for vagrant or other virtualized linux operating system. Docker for Mac does not provide the same docker daemon configuration options as other versions of docker-engine. macOS-socat uses socat to establish a tcp socket bound to localhost which makes available the Docker for Mac API.

### Example

To publish the unix-socket (**/var/run/docker.sock**) to the Docker daemon as port **2376** on the local host (127.0.0.1):
```
$ docker pull alpine/socat
$ docker run -d --restart=always \
    -p 127.0.0.1:2376:2375 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    alpine/socat \
    tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
```

***WARNING***: The Docker API is insecure by default. Please remember to bind the TCP socket to the `localhost` interface otherwise the Docker API will be bound to all interfaces.

## Use Case: Publish a port on an existing container

Docker does not allow easy publishing of ports on existing containers. Changing published ports is done by destroying existing containers and creating them with changed options. Alternative solutions require firewall access, and are vulnerable to changes in the addresses of said containers between restarts.

This image can be used to work-around these limitations by forwarding ports and linking containers

### Example

To publish port **1234** on container **example-container** as port **4321** on the docker host:
```
$ docker pull alpine/socat
$ docker run \
    --publish 4321:1234 \
    --link example-container:target \
    alpine/socat \
    tcp-listen:1234,fork,reuseaddr tcp-connect:target:1234
```
* To run the container in the background insert ```--detach``` after ```docker run```.
* To automatically start the container on restart insert ```--restart always``` after ```docker run```.
* To automatically start the container unless it has been stopped explicitly insert ```--restart unless-stopped``` after ```docker run```.

## Use Case: Use nginx-proxy to access a local Cockpit instance

Socat docker image by defintion does not use any EXPOSE inside Dockerfile. This may prejudice other containers that rely on this information, like nginx-proxy (https://github.com/nginx-proxy/nginx-proxy).

Using expose will allow nginx-proxy to properly detect and communicate with socat instance without opening the port on host like ports option does.

### Example
In the following example, socat will be used to relay a host Cockpit instance to the nginx-proxy image, allowing to rely on proxy ports and optional Let's Encrypt support.

```
  cockpit-relay:
    image: alpine/socat
    container_name: cockpit-relay
    depends_on:
      - nginx-proxy
    command: "TCP-LISTEN:9090,fork,reuseaddr TCP:172.17.0.1:9090"
    expose:
      - "9090"
    environment:
      - VIRTUAL_HOST=somehost.somedomain
      - VIRTUAL_PROTO=https
      - LETSENCRYPT_HOST=somehost.somedomain
      - LETSENCRYPT_EMAIL=some@email.somedomain
    restart: unless-stopped
    logging:
      driver: journald
    networks:
      - webservices
```

# The Processes to build this image

* Enable Travis CI cronjob on this repo to run build daily on master branch
* Check if there are new tags/releases announced via Alpine package url (https://hub.docker.com/r/alpine/socat/)
* Match the exist docker image tags via Hub.docker.io REST API
* If not matched, build the image with latest version as tag and push to hub.docker.com
* Docker tags as socat's version, such as 1.7.3.3-rc0, are built by travis ci auto-trigger cron jobs.
