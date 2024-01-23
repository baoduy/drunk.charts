# helm repo index drunk-app

helm uninstall drunk-app
helm install -f ./drunk-app/values.yaml drunk-app ./drunk-app