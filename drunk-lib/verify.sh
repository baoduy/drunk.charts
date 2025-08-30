#helm template test ./ --values ./values.yaml --output-dir ../_output --debug

helm package ./
helm repo index ./

# Find the latest .tgz file in the current directory and copy it to drunk-app/charts, overwriting if exists
latest_tgz=$(ls -t ./*.tgz | head -n1)
cp -f "$latest_tgz" ../drunk-app/charts/
