#helm template test ./ --values ./values.yaml --output-dir ../_output --debug

helm package ./
helm repo index ./

# Find the latest .tgz file in the current directory and copy it to drunk-app/charts, overwriting if exists
latest_tgz=$(ls -t ./*.tgz 2>/dev/null | head -n1)
if [ -z "$latest_tgz" ] || [ ! -f "$latest_tgz" ]; then
    echo "No .tgz files found"
    exit 1
fi
mkdir -p ../drunk-app/charts
cp -f "$latest_tgz" ../drunk-app/charts/
