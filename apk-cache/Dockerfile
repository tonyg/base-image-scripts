FROM debian:latest
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y squid-openssl
COPY ./squid.conf /etc/squid/conf.d/synit-squid.conf
RUN mkdir -p /var/spool/squid

CMD \
    chmod -R 0777 /var/spool/squid && \
    /etc/init.d/squid start && \
    tail -F /var/log/squid/access.log

EXPOSE 3130
