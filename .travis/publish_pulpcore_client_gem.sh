#!/bin/bash

openssl aes-256-cbc -K $encrypted_7ccb8decfcc9_key -iv $encrypted_7ccb8decfcc9_iv -in .travis/credentials.enc -out ~/.gem/credentials -d
sudo chmod 600 ~/.gem/credentials

django-admin runserver 24817 >> ~/django_runserver.log 2>&1 &
sleep 5

cd /home/travis/build/pulp/pulpcore/
export REPORTED_VERSION=$(http :24817/pulp/api/v3/status/ | jq --arg plugin pulpcore -r '.versions[] | select(.component == $plugin) | .version')
export DESCRIPTION="$(git describe --all --exact-match `git rev-parse HEAD`)"
if [[ $DESCRIPTION == 'tags/'$REPORTED_VERSION ]]; then
  export VERSION=${REPORTED_VERSION}
else
  export EPOCH="$(date +%s)"
  export VERSION=${REPORTED_VERSION}.dev.${EPOCH}
fi

export response=$(curl --write-out %{http_code} --silent --output /dev/null https://rubygems.org/gems/pulpcore_client/versions/$VERSION)

if [ "$response" == "200" ];
then
    exit
fi

cd
git clone https://github.com/pulp/pulp-openapi-generator.git
cd pulp-openapi-generator

sudo ./generate.sh pulpcore ruby $VERSION
sudo chown travis:travis pulpcore-client
cd pulpcore-client
gem build pulpcore_client
GEM_FILE="$(ls | grep pulpcore_client-)"
gem push ${GEM_FILE}
