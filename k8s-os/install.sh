helm lint ./ #--values ./values.yaml
helm install -f ./values.yaml win11 ./  --namespace drunk-os --create-namespace #--debug --dry-run