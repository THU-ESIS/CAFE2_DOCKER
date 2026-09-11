# syntax=docker/dockerfile:1

FROM node:24-bookworm-slim AS build
WORKDIR /CAFE/CAFE_PORTAL
ENV NPM_CONFIG_REGISTRY=https://registry.npmjs.org
COPY sources/CAFE2_PORTAL/package*.json ./
COPY sources/CAFE2_PORTAL/ .
# The v1 lockfile points at the retired registry.npm.taobao.org download URLs.
# Rewrite only the tarball host/path during the image build; package versions and
# integrity hashes remain those recorded in package-lock.json.
RUN node -e "const fs=require('fs');const p='package-lock.json';const l=JSON.parse(fs.readFileSync(p));const fix=(deps)=>Object.entries(deps||{}).forEach(([name,d])=>{if(d.resolved&&d.resolved.includes('registry.npm.taobao.org')){const base=name.startsWith('@')?name.split('/')[1]:name;d.resolved='https://registry.npmjs.org/'+name+'/-/'+base+'-'+d.version+'.tgz';}fix(d.dependencies)});fix(l.dependencies);fs.writeFileSync(p,JSON.stringify(l));"
RUN --mount=type=cache,id=cafe2-portal-npm,target=/root/.npm \
    npm ci --ignore-scripts

# Vue CLI 4 / webpack 4 may need the legacy OpenSSL provider on modern Node.
RUN NODE_OPTIONS=--openssl-legacy-provider npm run build

FROM node:12.22.12-buster-slim AS runtime
ARG VCS_REF=unknown
ARG IMAGE_VERSION=dev
LABEL org.opencontainers.image.source="https://github.com/THU-ESIS/CAFE2_DOCKER" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.version=$IMAGE_VERSION
WORKDIR /CAFE/CAFE_PORTAL
ENV NODE_ENV=production
ENV NPM_CONFIG_REGISTRY=https://registry.npmjs.org
COPY --from=build /CAFE/CAFE_PORTAL/package*.json ./
# sqlite3@4.1.1 has a prebuilt binary for Node 12's ABI. Run its install
# script in the runtime image rather than suppressing native-module setup.
RUN --mount=type=cache,id=cafe2-portal-npm,target=/root/.npm \
    npm ci --only=production
COPY --from=build /CAFE/CAFE_PORTAL/backend ./backend
COPY --from=build /CAFE/CAFE_PORTAL/configs ./configs
COPY --from=build /CAFE/CAFE_PORTAL/dist ./dist
EXPOSE 4000
CMD ["node", "backend/bin/app.js", "configs/config.json"]
