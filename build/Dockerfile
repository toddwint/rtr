FROM toddwint/mybaseimage
COPY app /opt/rtr
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    HTTPPORT1=8080 \
    HTTPPORT2=8081 \
    HTTPPORT3=8082 \
    HTTPPORT4=8083 \
    HUID=1001 \
    HGID=1001 \
    HOSTNAME=rtrsrvr \
    APPNAME=rtr
RUN apt-get update \
    && \
    apt-get install -y \
    iputils-ping \
    iputils-arping \
    && \
    echo $HOSTNAME > /etc/hostname \
    && \
    apt-get autoremove -y \
    && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /opt/rtr/debug
CMD ["/opt/rtr/scripts/startup.sh"]
