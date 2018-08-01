FROM debian:latest
RUN apt-get update
RUN apt-get install -y apt-cacher-ng
RUN sed -i -e 's/# Port:3142/Port:3129/g' /etc/apt-cacher-ng/acng.conf
RUN mkdir -p /var/cache/apt-cacher-ng
CMD chmod 0777 /var/cache/apt-cacher-ng && /etc/init.d/apt-cacher-ng start && tail -F /var/log/apt-cacher-ng/*
EXPOSE 3129
