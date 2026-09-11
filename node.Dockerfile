# syntax=docker/dockerfile:1

FROM maven:3.8-eclipse-temurin-21 AS java-build
WORKDIR /src
COPY sources/CAFE2_NODE/ .

# These are deliberately non-secret build-time defaults. The mounted
# /run/secrets/cafe2-jdbc.properties file overrides them at runtime.
RUN --mount=type=cache,target=/root/.m2 \
    sed -i \
      -e 's#<version>\[8\.0\.16,)</version>#<version>8.0.16</version>#' \
      -e 's#<version>\[2\.9\.10\.4,)</version>#<version>2.9.10.4</version>#' \
      -e 's#<version>\[24\.1\.1,)</version>#<version>24.1.1-jre</version>#' \
      -e 's#<version>\[4\.13\.1,)</version>#<version>4.13.1</version>#' \
      pom.xml && \
    mvn -B clean package \
    -Dmaven.test.skip=true \
    -DlogDir=/CAFE/log/node \
    -Djdbc.host=runtime-placeholder \
    -Djdbc.port=3306 \
    -Djdbc.user=runtime-placeholder \
    -Djdbc.password=runtime-placeholder \
    -Djdbc.database=runtime-placeholder

FROM tomcat:9.0.107-jdk21-temurin AS tomcat-base
ARG VCS_REF=unknown
ARG IMAGE_VERSION=dev
LABEL org.opencontainers.image.source="https://github.com/THU-ESIS/CAFE2_DOCKER" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.version=$IMAGE_VERSION
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=java-build /src/datamanager-web/target/datamanager-web.war \
    /usr/local/tomcat/webapps/datamanager.war
ENV CATALINA_OPTS="-Dfile.encoding=UTF-8"

FROM tomcat-base AS central

FROM tomcat-base AS worker-base
FROM mambaorg/micromamba:2.3.0 AS science-build
USER root
ENV MAMBA_ROOT_PREFIX=/opt/micromamba
RUN micromamba create --yes --prefix /opt/conda \
      --channel conda-forge \
      ncl=6.6.2 \
      cdo=2.5.0 \
      nco=5.3.3 \
      libnetcdf=4.9.2 \
      netcdf-fortran=4.6.1 \
    && micromamba clean --all --yes

FROM worker-base AS worker
COPY --from=science-build /opt/conda /opt/conda
COPY nclscripts/ /CAFE/nclscripts/
# Match the paths used by the current root-level ECS CAFE2 deployment.
# The scientific packages themselves are installed by micromamba under
# /opt/conda, so expose that environment at the ECS Miniconda path.
RUN mkdir -p /root && \
    ln -s /opt/conda /root/miniconda3
ENV PATH="/opt/conda/bin:${PATH}" \
    NCARG_ROOT="/root/miniconda3" \
    CAFE_TEMP_FOLDER="/CAFE/script_tmp/" \
    CAFE_NCL_PATH="/root/miniconda3/bin/ncl" \
    CAFE_NCL_ENV="NCARG_ROOT=/root/miniconda3" \
    CAFE_SCRIPT_FOLDER="/CAFE/nclscripts/"

FROM worker AS local
