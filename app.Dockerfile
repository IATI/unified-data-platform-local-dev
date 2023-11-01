FROM python:3.11-slim-bookworm

RUN apt-get update && apt install -y gcc libpq-dev busybox

COPY refresher/requirements_dev.txt  /tmp/requirements_dev.txt

RUN pip install -r /tmp/requirements_dev.txt

