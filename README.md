# iati-unified-data-platform-local-dev

## Requirements and pre-setup

You will need:

* Docker
* Docker Compose
* Git and Github
* Azure command line tools

And you will need to:

* Stop any other instances of Azurite

## Installation and initial setup

### 1. Clone this repository

Clone this repository

Change into the directory it was cloned into

### 2. Checkout other local code

Check out the other needed code (in the directory in which you cloned this repository):

```commandline
git clone  --recurse-submodules git@github.com:IATI/datastore-solr-configs.git datastore-solr-configs
git clone git@github.com:IATI/refresher.git refresher
```

(We don't use Git Submodules here cos we don't want to lock commit, you may want the latest version or a specific version, 
depending on what you are developing.)


### 3. Start docker compose

```
docker compose up
```

The next step in initial setup requires this to be running.

### 4. Setup Azurite storage containers and Solr

To setup both the Azure storage and Solr, run the following from outside docker:

```
./first_time_setup.sh
```

### 5. Check setup

To check the setup, we can use the Azure cli tools. The Azure cli tools require the `AZURE_STORAGE_CONNECTION_STRING`
environment variable to be set. This can be done by running the following command on the host machine (outside docker):

```
source ./set_azure_dev_env_var.sh
```

You can now use the following command to check the Azure storage containers have been created:

```
az storage container list --output table
```

You should see something like:

```
Name             Lease Status    Last Modified
---------------  --------------  -------------------------
clean                            2023-10-10T19:31:14+00:00
lake                             2023-10-10T19:31:15+00:00
source                           2023-10-10T19:23:12+00:00
validator-adhoc                  2023-10-10T19:31:16+00:00
```

You can check Solr is running by visiting http://localhost:8989/solr/#/ 

**Note: if you need to, you can change the ports for Postgres and Solr by editing `.env`**

## Usage

### Start docker compose

Start the refresher with:

```
docker compose up
```

### General commands

#### The `az` command

You can use the Azure `az` command to (e.g.) inspect/debug the Azurite storage containers. To do so, the
`AZURE_STORAGE_CONNECTION_STRING` needs to be set in the current terminal window. Use the `source` command to do 
this in any terminal where you want to run `az`:

```
source ./set_azure_dev_env_var.sh
```

#### To get a shell in the refresher container to run commands in

To run first one:

```
docker compose run -it iati-refresher-app bash
```

To get a second shell into this one (if you want to inspect a running process):

```
docker compose exec iati-refresher-app bash
```

The source code for the refresh is in `/work/refresher`

#### Connect to the Refresher's DB

You can connect to the database (from outside docker) with any client using the following details:

DB name: `refresher`  
DB user: `refresh`  
DB pass: `pass`  
DB Port: `5437` (although changeable via `.env`)  

For example, to connect using `psql` the command is:

```
psql -h localhost -U refresh -W refresher -p 5437
```

#### Connect to Solr

Visit http://localhost:8983/solr/#/  
 


### Running the Unified Data Platform: Refresh stage

#### Optional (depending on dev task)

The Refresher downloads a lot of data; to limit the amount of data it downloads and processes during local development, 
the  following changes can be made on the host machine:

In `src/library/refresher.py`, change:
* `get_paginated_response` - alter both return statements to just say `return retval`
* `fetch_datasets` - delete the while loop

Then, either, to fetch the data for just 10 publishers, change (still in `src/library/refresher.py`): 
* `sync_publishers` - change the call to `get_paginated_response` to get only 10 responses (by changing 1000 to 10)

Or, to fetch the data for a specified publisher, change:
* `sync_publishers` - after `for publisher_name in publisher_list:` add `if publisher_name != "ec-echo": continue`
The value `ec-echo` can be changed to any publisher name, if you want the data for a specific publisher.

#### Refresh stage

Connect to the `iati-refresher-app` docker container (using `run` command above, or `exec` command if already
running).

Change into the `/work/refresher` directory, and run the Refresher with the following command:

```
python src/handler.py -t refresh
```

This command will fetch the list of publishers and the list of documents associated with those publishers from the
Registry. (If it is the first run it will create the database structure). 

After running, you should be able to connect to the database and see some data in the `document` and `publisher` tables. (There will
probably be a lot of `insert or update on table "document" violates foreign key constraint "related_publisher"` errors 
but as long as there is some data in the `document` and `publisher` tables you have something to work with.)

#### Download XML stage

The following command (also to be run on the Refresher container) will attempt to download the
documents that are listed in the `document` table:

```
python src/handler.py -t reload
```

You can check that this has been successful by running the following from the host machine (outside docker):

```
az storage blob list --account-name devstoreaccount1  --container-name source --output table
```

If required, you can download an XML file from the Azurite `source` container with the following command (run on host machine):

```
az storage blob download  --account-name devstoreaccount1   --container-name source  --name 55eb708035ffd2e27c174a9be956b3ef446484a9.xml > FILENAME.xml
```

This will save the XML in `FILENAME.xml`; all being well, this should be an IATI XML file.


### Running the Unified Data Platform: Validate Stage

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

### Running the Unified Data Platform: Clean

```
python src/handler.py -t  copy_valid
python src/handler.py -t  clean_invalid
```

### Running the Unified Data Platform: Flatten

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



### Running the Unified Data Platform: Lakify

```
python src/handler.py -t lakify
```



### Running the Unified Data Platform: Solrize


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





