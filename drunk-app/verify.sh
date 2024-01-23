rm -rf ./_test
helm template test ./ --values ./values.yaml --output-dir ./_test
helm package ./
#helm install -f ./values.yaml hello-world ./ --dry-run
helm repo index ./