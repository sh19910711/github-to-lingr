#!/bin/bash

if [[ "${TRAVIS_BRANCH}" == "heroku/production" ]] || [[ "${TRAVIS_BRANCH}" == "heroku/development" ]]; then
  wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh
  if [[ "${TRAVIS_BRANCH}" == "heroku/production" ]]; then
    git remote add heroku git@heroku.com:${HEROKU_APP_ID_PRODUCTION}.git
  fi
  if [[ "${TRAVIS_BRANCH}" == "heroku/development" ]]; then
    git remote add heroku git@heroku.com:${HEROKU_APP_ID_DEVELOPMENT}.git
  fi
  echo "Host heroku.com" >> ~/.ssh/config
  echo "   StrictHostKeyChecking no" >> ~/.ssh/config
  echo "   CheckHostIP no" >> ~/.ssh/config
  echo "   UserKnownHostsFile=/dev/null" >> ~/.ssh/config
  heroku config:set GITHUB_TO_LINGR_VERSION=`git rev-parse ${TRAVIS_BRANCH}`
fi
