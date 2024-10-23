#helm template test ./ --values ./values.yaml --output-dir ../_output --debug

helm package ./
helm repo index ./