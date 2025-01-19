ARG GO_IMAGE=golang:1.23
ARG DEBIAN_IMAGE=debian:stable-slim
ARG BASE=gcr.io/distroless/static-debian12:nonroot

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS go-build
COPY . /policy
RUN git clone -b v1.12.0 --depth 1 https://github.com/coredns/coredns.git /go/src/github.com/coredns/coredns && \
    git config --global --add safe.director /go/src/github.com/coredns/coredns && \
    mkdir -p /go/src/github.com/coredns/coredns/plugin/policy && \
    cp /policy/plugin.cfg /go/src/github.com/coredns/coredns/ && \
    cd /go/src/github.com/coredns/coredns && go mod tidy && make coredns && cp coredns /

FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS build
SHELL [ "/bin/sh", "-ec" ]

RUN export DEBCONF_NONINTERACTIVE_SEEN=true \
           DEBIAN_FRONTEND=noninteractive \
           DEBIAN_PRIORITY=critical \
           TERM=linux ; \
    apt-get -qq update ; \
    apt-get -yyqq upgrade ; \
    apt-get -yyqq install ca-certificates libcap2-bin; \
    apt-get clean
COPY --from=go-build /coredns /coredns
RUN setcap cap_net_bind_service=+ep /coredns

FROM --platform=$TARGETPLATFORM ${BASE}
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /coredns /coredns
USER nonroot:nonroot
WORKDIR /
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
