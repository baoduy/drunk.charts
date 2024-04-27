rm -rf ../_output
helm lint ./ #--values ./values.yaml
helm template hoppscotch ./ --values ./values.local.yaml --output-dir ../_output --debug
#helm package ./
#helm install -f ./values.local.yaml hoppscotch ./ --create-namespace --namespace hoppscotch --debug --dry-run
#helm repo index ./