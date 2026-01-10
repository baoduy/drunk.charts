#!/bin/bash

helm template test ../drunk-app --values ./values.yaml --output-dir ../_output --debug