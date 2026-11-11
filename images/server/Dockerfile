# BASE is the upstream server image, built from deployment/self-host/Dockerfile.
ARG BASE=nod-server-upstream
FROM registry.k8s.io/kubectl:v1.37.2@sha256:fe049faa65ae483ac200009a949a68fa4c9985daea12c9cb1195c9c7965301fc AS kubectl

FROM ${BASE}
COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl
COPY --chmod=555 docker /usr/local/bin/docker
