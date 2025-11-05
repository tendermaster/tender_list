#!/bin/bash
pwd
echo "1" >> "f.log"

# 1. Clean up previous server process
echo "Removing old server.pid"
rm -f tmp/pids/server.pid

# 2. Ensure all gems are installed
echo "Checking bundle..."
bundle check || bundle install --jobs 4 --retry 3

bundle install
yarn install

rails assets:clobber
rails assets:precompile

# 3. Prepare the database
# This creates the DB if it doesn't exist and runs migrations.
echo "Preparing database..."
# bundle exec rails db:prepare
# 2. Check for the ROLE environment variable, default to 'web' if not set
echo $ROLE
echo "Container role is: $ROLE"

# 3. Conditionally prepare the database
if [ "$ROLE" = "web" ]; then
  echo "Running as web service. Preparing database..."
  bundle exec rails db:prepare
else
  echo "Running as worker service. Skipping database preparation."
fi

# 4. Execute the main command passed from docker-compose
# This will be `rails s` for the web service and `sidekiq` for the worker service.
# echo "Executing command: $@"

# last line
# exec "$@"
# rails s -b 0.0.0.0
npx concurrently 'rails s -b 0.0.0.0' 'bundle exec sidekiq'
