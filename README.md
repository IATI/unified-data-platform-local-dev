# iati-unified-data-platform-local-dev

## Requirements

* Docker
* Docker Compose
* Azure command line tools

## Checkout other local code

You'll need to do this the first time you run this (before running `up`).

Check out other needed code:

```commandline
git clone  --recurse-submodules git@github.com:IATI/datastore-solr-configs.git datastore-solr-configs
git clone git@github.com:IATI/refresher.git refresher
```

(We don't use Git Submodules here cos we don't want to lock commit, you may want the latest version or a specific version, 
depending on what you are developing.)

## To get dev env

```
docker compose up
```

Later commands & sections assume this is running.

## Setup local code & servers

You'll need to do this the first time you run this.

From outside docker:

```
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:10000/devstoreaccount1;QueueEndpoint=http://localhost:10001/devstoreaccount1;TableEndpoint=http://localhost:10002/devstoreaccount1;"
az storage container create --name source
az storage container create --name clean
az storage container create --name lake
az storage container create --name validator-adhoc
docker compose exec  -it  iati-refresher-solr  solr create_core -c activity_solrize -d /datastore-solr-configs/configsets/activity/conf
docker compose exec  -it  iati-refresher-solr  solr create_core -c transaction_solrize -d /datastore-solr-configs/configsets/transaction/conf
docker compose exec  -it  iati-refresher-solr  solr create_core -c budget_solrize -d /datastore-solr-configs/configsets/budget/conf
```

## To get a shell to run commands in

To run first one:

```
docker compose run -it iati-refresher-app bash
```

To get shell into this one (if you want to inspect a running process):


```
docker compose exec iati-refresher-app bash
```

After getting access, to use the refresher you'll want to:

```
cd /work/refresher
```


## Connect to DB

From outside docker:

```
psql -h localhost -U refresh -W refresher
```

Password is pass


## Connect to Solr

http://localhost:8983/solr/#/


## Get a file from local storage

From outside docker:

```
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:10000/devstoreaccount1;QueueEndpoint=http://localhost:10001/devstoreaccount1;TableEndpoint=http://localhost:10002/devstoreaccount1;"
az storage blob download  --account-name devstoreaccount1   --container-name source  --name 55eb708035ffd2e27c174a9be956b3ef446484a9.xml > out.json
```

## Run stage: Refresh

src/library/refresher.py
* `get_paginated_response` - change both return statements to just say return retval
* `sync_publishers` - only get 10 responses 
* `fetch_datasets` - delete while loop

Or to get to one publisher only
* `sync_publishers` - after `for publisher_name in publisher_list:` add `if publisher_name != "ec-echo": continue`

Run:
```
python src/handler.py -t refresh
python src/handler.py -t reload
```

There will probably be a lot of `insert or update on table "document" violates foreign key constraint "related_publisher"` errors 
but as long as `select count(*) from document;` shows some results ignore it and move on

## Run stage: Validate

Install and set up https://github.com/IATI/js-validator-api

Your .env should these changes (make a github classic access token with no special scopes selected) (get VALIDATOR_SERVICES* from keypass):
```
REDIS_HOSTNAME=redis
BASIC_GITHUB_TOKEN=xxxxxxxx
APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://opendataservices.coop/;LiveEndpoint=https://opendataservices.coop/;ProfilerEndpoint=https://opendataservices.coop/;SnapshotEndpoint=https://opendataservices.coop/;"
VALIDATOR_SERVICES_URL=xxxxxxxxxxxxx
VALIDATOR_SERVICES_KEY_NAME=xxxxxxxxxxxxx
VALIDATOR_SERVICES_KEY_VALUE=xxxxxxxxxxxxxxxxx
```


You may need to apply https://github.com/IATI/js-validator-api/issues/483

In the following files change `"authLevel": "function"` to `"authLevel": "anonymous"`:
* pub-validate-post/function.json
* pvt-schema-validate-file-post/function.json

Run service with Docker Compose Option:

```
npm run docker:start
```

When service ready, run:

```
python src/handler.py -t validate
```

If you see the following log messages:

    Skipping Schema Invalid file for Full Validation until 2hrs after download

Edit `src/library/validate.py`, search for the 2 code blocks with `Skipping Schema Invalid file for Full Validation until` and remove them.

## Run stage: Clean

```
python src/handler.py -t  copy_valid
python src/handler.py -t  clean_invalid
```

## Run stage: Flatten

Get https://github.com/IATI/iati-flattener

Run flatterer:

```
npm i
APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://opendataservices.coop/;LiveEndpoint=https://opendataservices.coop/;ProfilerEndpoint=https://opendataservices.coop/;SnapshotEndpoint=https://opendataservices.coop/;" npm start
```

When service ready, run:

```
python src/handler.py -t flatten
```



## Run stage: Lakify

```
python src/handler.py -t lakify
```



## Run stage: Solrize


```
python src/handler.py -t solrize
```

## Running Validator Services against local copy


https://github.com/IATI/validator-services

Edit `.env`:

```
NODE_ENV=development

PGDATABASE=refresher
PGHOST=localhost
PGPASSWORD=pass
PGPORT=5432
PGUSER=refresh

# name of adhoc azure blob container
ADHOC_CONTAINER=validator-adhoc

# validator API url and api key
VALIDATOR_API_URL=
VALIDATOR_FUNC_KEY=
```

Edit `local.settings.json`:

```
{
    "IsEncrypted": false,
    "Values": {
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "AzureWebJobsStorage": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:10000/devstoreaccount1;QueueEndpoint=http://localhost:10001/devstoreaccount1;TableEndpoint=http://localhost:10002/devstoreaccount1;",
        "STORAGECONNECTOR": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:10000/devstoreaccount1;QueueEndpoint=http://localhost:10001/devstoreaccount1;TableEndpoint=http://localhost:10002/devstoreaccount1;",
        "ADHOC_CONTAINER": "validator-adhoc"
    }
}
```

Edit `package.json`, and in the start script change the CORS port:

```
        "start": "func start --javascript --cors http://localhost:4173",
```


In all the function.js files change `"authLevel": "function"` to `"authLevel": "anonymous"`:


Run:

```
npm i
npm start
```


## Running Validator Web against local copy

You need Validator services running - see above.

https://github.com/IATI/validator-web


Edit `envs/.env.development`:

```
VUE_ENV_ENVIRONMENT=development
VUE_ENV_DEV_TOOLS=true
VUE_ENV_BASE_URL=http://localhost:4173
VUE_ENV_VALIDATOR_SERVICES_URL=http://localhost:7071/api
VUE_ENV_VALIDATOR_SERVICES_KEY_NAME=X
VUE_ENV_VALIDATOR_SERVICES_KEY_VALUE=Y
VUE_ENV_GUIDANCE_LINK_BASE_URL=https://iatistandard.org/en/iati-standard
PLAUSIBLE_DOMAIN=localtest
VUE_ENV_SHOW_MAINTENANCE_BANNER=false

```


Run:

```
npm i
npm run build:development
npm run preview
```





