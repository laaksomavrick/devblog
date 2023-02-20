#!/usr/bin/env sh

# Assumption: aws cli installed and configured

set -o allexport && source ./scripts/.env && set +o allexport

# Install dependencies
npm ci

# Build artifact
make build-staging

# Deploy to s3
aws s3 sync public $BUCKET_ID

# Invalidate cloudfront cache
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*";
