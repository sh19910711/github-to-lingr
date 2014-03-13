#!/bin/bash

if [[ "${TRAVIS_BRANCH}" == "heroku/production" || "${TRAVIS_BRANCH}" == "heroku/development" ]]; then
  wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh
  HEROKU_APP_ID=""
  if [ "${TRAVIS_BRANCH}" == "heroku/production"  ]; then
    HEROKU_APP_ID=${HEROKU_APP_ID_PRODUCTION}
  fi
  if [ "${TRAVIS_BRANCH}" == "heroku/development"  ]; then
    HEROKU_APP_ID=${HEROKU_APP_ID_DEVELOPMENT}
  fi
  git remote add heroku git@heroku.com:${HEROKU_APP_ID}.git
  echo "Host heroku.com" >> ~/.ssh/config
  echo "   StrictHostKeyChecking no" >> ~/.ssh/config
  echo "   CheckHostIP no" >> ~/.ssh/config
  echo "   UserKnownHostsFile=/dev/null" >> ~/.ssh/config
  heroku config:set GITHUB_TO_LINGR_VERSION=`git rev-parse ${TRAVIS_BRANCH}` --app ${HEROKU_APP_ID}
fi
