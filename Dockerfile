# The Tessera application: one image, one process.
#
# Seven Go modules produce one container. That is not a contradiction — a module
# is a source boundary, not a deployment boundary. The split exists so that a
# program embedding the parser does not inherit an AWS SDK to do it; it was
# never meant to imply seven things to run.
#
# What ships here is the application: a web interface, and the command-line
# tools beside it for people who would rather script than click. Signing and
# offline data bundles are included because an operator working across an air
# gap needs them in the same place as everything else, and asking them to
# assemble a toolchain on the far side of a gap is asking them not to bother.
#
# The Kubernetes operator is a separate image and a separate decision. Nobody
# should need a cluster to scan a model.

FROM golang:1.25-alpine AS build
RUN apk add --no-cache git
WORKDIR /src

# Each module is fetched and built independently. They are separate modules, so
# there is no workspace to share; copying the manifests first keeps the download
# layer cached when only source changes.
ARG TESSERA_VERSION=dev

COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath \
    -ldflags "-s -w -X main.version=${TESSERA_VERSION}" \
    -o /out/tessera-studio ./cmd/tessera-studio

# The sibling tools come from their published modules rather than a local copy,
# so the image is built from the same artifacts anybody else would install.
ARG TESSERA_CLI_VERSION=v0.4.7
ARG TESSERA_SIGN_VERSION=v0.2.0
ARG TESSERA_BUNDLE_VERSION=v0.1.0
ENV CGO_ENABLED=0 GOBIN=/out
# Each tool is stamped with the version actually installed. A binary that
# reports "dev" cannot be matched to a release, which makes the image it sits in
# unauditable — an awkward property for a tool whose subject is provenance.
RUN go install -trimpath -ldflags "-s -w -X main.version=${TESSERA_CLI_VERSION}" \
      github.com/DAVANO-INNOVATION-LAB/tessera/cmd/tessera@${TESSERA_CLI_VERSION} && \
    go install -trimpath -ldflags "-s -w -X main.version=${TESSERA_SIGN_VERSION}" \
      github.com/DAVANO-INNOVATION-LAB/tessera-sign/cmd/tessera-sign@${TESSERA_SIGN_VERSION} && \
    go install -trimpath -ldflags "-s -w -X main.version=${TESSERA_BUNDLE_VERSION}" \
      github.com/DAVANO-INNOVATION-LAB/tessera-bundle/cmd/tessera-bundle@${TESSERA_BUNDLE_VERSION}

# Nothing from the toolchain survives into the running image. There is no shell,
# no package manager and no interpreter — which is the right shape for something
# whose job is to open files it does not trust.
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/tessera-studio  /usr/local/bin/tessera-studio
COPY --from=build /out/tessera         /usr/local/bin/tessera
COPY --from=build /out/tessera-sign    /usr/local/bin/tessera-sign
COPY --from=build /out/tessera-bundle  /usr/local/bin/tessera-bundle

# Models are mounted read-only. The application never writes to them, and saying
# so in the image is worth more than saying so in a document nobody reads.
VOLUME ["/models"]
EXPOSE 7777
USER nonroot:nonroot

# Binding to every interface is deliberate here and only here: inside a
# container, loopback would be unreachable from outside it, so the host decides
# exposure by how it publishes the port. The standalone binary still defaults to
# loopback, because on a laptop the default should be the safe one.
ENTRYPOINT ["/usr/local/bin/tessera-studio"]
CMD ["--addr", "0.0.0.0:7777", "/models"]
