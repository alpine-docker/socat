# socat

Run socat command in alpine container


## use case

Expose a tcp socket for accessing docker API on macOS

The Docker for Mac native macOS application provides use of docker engine without the need for vagrant or other virtualized linux operating system. Docker for Mac does not provide the same docker daemon configuration options as other versions of docker-engine. macOS-socat uses socat to establish a tcp socket bound to localhost which makes available the Docker for Mac API.

### Getting Started
```
$ docker pull alpine/socat
$ docker run -d --restart=always \
    -p 127.0.0.1:2376:2375 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    alpine/socat \
    TCP4-LISTEN:2375,fork,reuseaddr UNIX-CONNECT:/var/run/docker.sock
```

***WARNING***: The Docker API is unsecure by default. Please remember to bind the TCP socket to the localhost interface otherwise the Docker API will be bound to all interfaces.
