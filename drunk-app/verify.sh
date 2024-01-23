rm -rf ./_test
helm template test ./ --values ./values.yaml --output-dir ./_test
helm package ./ --app-version "1.0.0"
helm install -f ./values.yaml hello-world ./ --dry-run