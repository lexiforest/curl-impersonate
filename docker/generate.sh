#!/bin/sh

cat <<EOF | mustache - Dockerfile.mustache > debian.dockerfile
---
debian: true
---
EOF

cat <<EOF | mustache - Dockerfile.mustache > alpine.dockerfile
---
alpine: true
---
EOF
