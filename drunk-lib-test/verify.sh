rm -rf ../_output

helm template test ./ --values ./values.yaml --output-dir ../_output --debug
#helm install -f ./values.yaml -f ./values.test.yaml test ./ --debug --dry-run
#sleep 5

helm package ./
helm repo index ./
#sleep 5

helm lint --values ./values.yaml ./