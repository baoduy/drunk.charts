# helm repo index drunk-app
helm repo add drunk-app https://baoduy.github.io/hbd.charts/drunk-app
helm repo update
helm uninstall ms-hello-app
helm install -f ./values.yaml ms-hello-app drunk-app/drunk-app