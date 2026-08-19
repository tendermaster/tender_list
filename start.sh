#!/bin/bash
#pwd
#echo "1" >> "f.log"

# 1. Clean up previous server process
echo "Removing old server.pid"
rm -f tmp/pids/server.pid

# 2. Ensure bundle is satisfied
bundle check || bundle install --jobs 4 --retry 3

# 3. Precompile assets only if explicitly requested or if public/assets is missing
if [ "$PRECOMPILE_ASSETS" = "true" ] || [ ! -d "public/assets" ]; then
  echo "Precompiling assets..."
  bundle exec rails assets:precompile
fi

# 3. Execute web server or worker based on ROLE
if [ "$ROLE" = "worker" ]; then
  echo "Starting Sidekiq worker..."
  exec bundle exec sidekiq
else
  echo "Starting Rails web server..."
  exec bundle exec rails s -b 0.0.0.0
fi
