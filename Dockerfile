FROM registry.astralinux.ru/library/alse:1.7.3 AS builder

#install make
RUN set -eux && \
    apt-get update && \
    apt-get install make

#copy all folders and files for build and config
COPY archive_for_build_temporal.tar.gz /archive_for_build_temporal.tar.gz
RUN tar -xzvf /archive_for_build_temporal.tar.gz -C /usr/src

#set golang BIN repository
ENV PATH=$PATH:/usr/src/go/bin

#unarchive packages for golang to build temporal and dockerize
COPY go_packages.tar.gz /go_packages.tar.gz
RUN mkdir -p ~/go && tar -xzvf /go_packages.tar.gz -C ~/go

#build temporal (creates bin in makefile's folder)
RUN make /usr/src/temporal-1.22.2/temporal-server

#dockerize's makefile creates BIN into root/go/bin/dockerize
#error without command WORKDIR
WORKDIR /usr/src/dockerize-0.7.0/
RUN make dockerize

##################
FROM temporaliotest/admin-tools as admin-tools
#FROM temporaliotest/server as server
#import configs for auto-setup
FROM registry.astralinux.ru/library/alse:1.7.3 as final

WORKDIR /etc/temporal
COPY --from=admin-tools /usr/local/bin/temporal-cassandra-tool /usr/local/bin
COPY --from=admin-tools /usr/local/bin/temporal-sql-tool /usr/local/bin
COPY --from=admin-tools /etc/temporal/schema /etc/temporal/schema

#adding auto-setup srcipts
COPY --from=builder /usr/src/docker-auto-setup/* /etc/temporal/

#adding configs
COPY --from=builder /usr/src/temporal-1.22.2/temporal-server /usr/local/bin/temporal-server
COPY --from=builder /usr/src/temporal-1.22.2/docker/config_template.yaml /etc/temporal/config/config_template.yaml
COPY --from=builder root/go/bin/dockerize /usr/local/bin/dockerize

CMD ["autosetup"]
ENTRYPOINT ["/etc/temporal/entrypoint.sh"]