# syntax=docker/dockerfile:1
FROM ruby:3.2.9

WORKDIR /app

ARG UID=1004
ARG GID=1004
RUN uname -a
RUN apt-get update && apt-get install -y apt-transport-https

RUN bash -c "set -o pipefail && apt-get update \
  && apt-get install -y --no-install-recommends build-essential curl git libpq-dev tzdata iputils-ping gnupg \
  && curl -sSL https://deb.nodesource.com/setup_24.x | bash - \
  && mkdir -p /etc/apt/keyrings \
  && curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg \
  && echo 'deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs yarn \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
  && apt-get clean \
  && groupadd -g 1004 ruby \
  && useradd --create-home --no-log-init -u 1004 -g 1004 ruby \
  && mkdir -p /usr/local/bundle \
  && chown ruby:ruby -R /app /usr/local/bundle"

USER ruby

ARG RAILS_ENV="production"
ARG NODE_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
  NODE_ENV="${NODE_ENV}" \
  USER="ruby" \
  TZ="Asia/Kolkata"


# --- Optimized Dependency Installation with BuildKit Cache ---

# 1. Copy Gemfile and Gemfile.lock
COPY --chown=ruby:ruby Gemfile Gemfile.lock ./

# 2. Install gems with BuildKit cache mount
RUN --mount=type=cache,id=bnd-cache,target=/usr/local/bundle/cache,uid=1004,gid=1004 \
    bundle install --jobs 4 --retry 3

# 3. Copy package.json and yarn.lock
COPY --chown=ruby:ruby package.json yarn.lock ./

# 4. Install node modules with BuildKit cache mount
RUN --mount=type=cache,id=yarn-cache,target=/home/ruby/.cache/yarn,uid=1004,gid=1004 \
    yarn install

# NOTE: We DO NOT copy the rest of the application code.
# The `volumes` mount in docker-compose.yml will provide it at runtime.

# Copy and set up the entrypoint script
# COPY entrypoint.sh /usr/bin/
# RUN chmod +x /usr/bin/entrypoint.sh
# ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

# 7. DEFINE THE DEFAULT COMMAND
# This is the command that will run when the container starts if not
# overridden in docker-compose.yml.
# It becomes the default argument to the ENTRYPOINT script.
# CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
CMD ["bash", "start.sh"]
