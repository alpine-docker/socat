# socat

Run socat command in alpine container

[![DockerHub Badge](http://dockeri.co/image/alpine/socat)](https://hub.docker.com/r/alpine/socat/)


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

***WARNING***: The Docker API is unsecure by default. Please remember to bind the TCP socket to the localhost interface otherwise the Docker API will be bound to all interfaces.

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
