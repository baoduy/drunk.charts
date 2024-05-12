rm -rf ../_output

helm template drunk-squid-proxy ./ --values ./values.local.yaml --output-dir ../_output --debug
helm lint ./ #--values ./values.yaml

helm package ./
helm repo index ./
