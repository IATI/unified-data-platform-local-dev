#!/bin/bash

# this command should be run after 'docker compose up' is working

export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:13000/devstoreaccount1;QueueEndpoint=http://localhost:13001/devstoreaccount1;TableEndpoint=http://localhost:13002/devstoreaccount1;"

echo "Running storage container create --name source"
az storage container create --name source

echo "Running storage container create --name clean"
az storage container create --name clean

echo "Running az storage container create --name lake"
az storage container create --name lake

echo "Running az storage container create --name validator-adhoc"
az storage container create --name validator-adhoc

echo "Running az storage queue create --name publisher-black-flag-remove"
az storage queue create --name publisher-black-flag-remove


echo "Creating Solr cores for activities, transactions, and budgets"
docker compose exec  -it  iati-refresher-solr  solr create_core -c activity_solrize -d /datastore-solr-configs/configsets/activity/conf
docker compose exec  -it  iati-refresher-solr  solr create_core -c transaction_solrize -d /datastore-solr-configs/configsets/transaction/conf
docker compose exec  -it  iati-refresher-solr  solr create_core -c budget_solrize -d /datastore-solr-configs/configsets/budget/conf
