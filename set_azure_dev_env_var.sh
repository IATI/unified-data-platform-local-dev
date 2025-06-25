(return 0 2>/dev/null) && sourced=1 || sourced=0

if [ $sourced == 0 ]; then
  echo "Executing this script directly won't export the env var into your shell"
  echo "Run 'source ./set_azure_dev_env_var.sh' instead"
else
  export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:13000/devstoreaccount1;QueueEndpoint=http://localhost:13001/devstoreaccount1;TableEndpoint=http://localhost:13002/devstoreaccount1;"
  echo "Exported AZURE_STORAGE_CONNECTION_STRING environment variable into your shell"
fi
