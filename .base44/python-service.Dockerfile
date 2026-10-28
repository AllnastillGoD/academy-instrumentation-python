# Base44 development image for the Python services of the Meminator sample app.
#
# It installs ONLY the pinned Python dependencies (and any extra OS packages the
# service needs) at build time. Application source is never copied into the
# image: docker-compose.base44.yml bind-mounts each service directory at /app,
# so code edits are picked up by Flask's reloader without rebuilding.
#
# Build args:
#   SERVICE_PATH  path of the service directory, e.g. services/meminator-python
#   APT_PACKAGES  extra Debian packages to install (e.g. "imagemagick fontconfig")
FROM python:3.11-slim

ARG SERVICE_PATH=services/backend-for-frontend-python
ARG APT_PACKAGES=""

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ${APT_PACKAGES}; \
    rm -rf /var/lib/apt/lists/*

COPY ${SERVICE_PATH}/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /app
