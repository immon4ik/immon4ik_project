FROM golang:1.13.10

WORKDIR /go/src/github.com/percona/mongodb_exporter

RUN git clone -b v0.11.0 https://github.com/percona/mongodb_exporter.git ./

RUN make build

FROM prom/busybox:latest

COPY --from=0 /go/src/github.com/percona/mongodb_exporter/bin/mongodb_exporter /bin/mongodb_exporter

EXPOSE 9216

ENTRYPOINT ["/bin/mongodb_exporter"]
