rm -rf ../_output
helm lint --values ./values.yaml ./
helm template test ./ --values ./values.test.yaml --output-dir ../_output --debug
helm package ./
helm install -f ./values.test.yaml test ./ --debug --dry-run
helm repo index ./