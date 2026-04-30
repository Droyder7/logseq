# NOTE: please keep it in sync with .github pipelines
# NOTE: during testing make sure to change the branch below
# NOTE: before running the build-docker GH action edit
#       build-docker.yml and change the release channel from :latest to :testing

# Builder image
FROM clojure:temurin-11-tools-deps-1.11.1.1208-bullseye-slim as builder

ARG DEBIAN_FRONTEND=noninteractive

# Install reqs
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    ca-certificates-java \
    apt-transport-https \
    gpg \
    openssl \
    xz-utils \
    build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev

RUN update-ca-certificates -f

RUN openssl s_client -showcerts -connect repo.clojars.org:443 -servername repo.clojars.org </dev/null 2>/dev/null | \
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > /tmp/repo-clojars.pem && \
    keytool -importcert -noprompt -alias repo-clojars -file /tmp/repo-clojars.pem \
      -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit || true

# install NodeJS + pnpm from official binaries
RUN ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "arm64" ]; then NODE_ARCH="arm64"; else NODE_ARCH="x64"; fi && \
    curl -kfsSL "https://nodejs.org/dist/v24.10.0/node-v24.10.0-linux-${NODE_ARCH}.tar.xz" -o /tmp/node.tar.xz && \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && \
    rm -f /tmp/node.tar.xz && \
    corepack enable && corepack prepare pnpm@10.33.0 --activate

WORKDIR /data

# build Logseq static resources
COPY . .

ENV npm_config_nodedir=/usr/local
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

RUN pnpm install --config.network-timeout=240000

ENV JAVA_TOOL_OPTIONS="-Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true"

RUN pnpm release

# Web App Runner image
FROM nginx:1.24.0-alpine3.17

COPY --from=builder /data/static /usr/share/nginx/html
