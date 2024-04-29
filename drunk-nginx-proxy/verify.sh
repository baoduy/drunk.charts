rm -rf ../_output
helm lint ./ #--values ./values.yaml
helm template test ./ --values ./values.test.yaml --output-dir ../_output --debug
helm install -f ./values.test.yaml dev-proxy ./ --create-namespace --namespace dc-proxy --debug --dry-run

helm package ./
helm repo index ./