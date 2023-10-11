FROM python:3.11-slim-bookworm

RUN apt-get update && apt install -y gcc libpq-dev busybox

COPY refresher/requirements.txt  /tmp/requirements.txt

RUN pip install -r /tmp/requirements.txt 
