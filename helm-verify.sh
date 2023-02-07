rm -r cloudflare-tunnels-template
helm package cloudflare-tunnels --app-version 1.0.0 --version 1.0.0
helm lint cloudflare-tunnels cloudflare-tunnels-1.0.0.tgz -f cloudflare-tunnels/values.yaml
#helm install cloudflare-tunnels cloudflare-tunnels-1.0.0.tgz --namespace default -f cloudflare-tunnels/values.yaml --dry-run
helm template cloudflare-tunnels cloudflare-tunnels-1.0.0.tgz --namespace default -f cloudflare-tunnels/values.yaml --output-dir cloudflare-tunnels-template