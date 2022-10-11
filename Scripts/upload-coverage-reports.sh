#!/bin/bash -l
set -ex

IFS=','; PLATFORMS=$(echo $1); unset IFS

for PLATFORM in $PLATFORMS; do
	bash <(curl -s https://codecov.io/bash) -J '^CacheAdvance(.framework)?$' -D .build/derivedData/$PLATFORM -t 8344b011-6b2a-4b3d-a573-eaf49684318e
	bash <(curl -s https://codecov.io/bash) -J '^CADCacheAdvance(.framework)?$' -D .build/derivedData/$PLATFORM -t 8344b011-6b2a-4b3d-a573-eaf49684318e
done
