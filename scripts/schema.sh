#!/bin/sh
# Converts schema/values.schema.yml into chart/values.schema.json.

set -eu

dir="$(realpath "$(dirname "$0")/..")"

# renovate: datasource=go packageName=github.com/mikefarah/yq/v4 depName=yq
YQ_VERSION="v4.54.1"

go run "github.com/mikefarah/yq/v4@$YQ_VERSION" \
  --output-format json --indent 0 \
  "$dir/schema/values.schema.yml" > "$dir/chart/values.schema.json"
