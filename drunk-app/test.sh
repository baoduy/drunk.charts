# helm plugin remove unittest
# helm plugin install https://github.com/helm-unittest/helm-unittest.git

helm unittest -f 'tests/*.yaml' ./
