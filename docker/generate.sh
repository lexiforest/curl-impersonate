#!/bin/sh

cat <<EOF | mustache - Dockerfile.mustache > docker/debian.dockerfile
---
debian: true
---
EOF

cat <<EOF | mustache - Dockerfile.mustache > chrome/alpine.dockerfile
---
alpine: true
---
EOF
