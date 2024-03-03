rm -rf ../_test
helm template test ./ --values ./values.test.yaml --output-dir ../_test --debug
helm package ./
#helm install -f ./values.yaml hello-world ./ --dry-run
helm repo index ./