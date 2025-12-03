FROM ruby:3.4.7

# RUN apt update -qq && apt install -y build-essential libpq-dev nodejs yarn
# RUN ln -s $(which yarn) /usr/local/bin/yarn && \
#     ln -s $(which node) /usr/local/bin/node
WORKDIR /app

ARG UID=1004
ARG GID=1004
RUN uname -a
RUN apt update && apt install -y apt-transport-https

RUN bash -c "set -o pipefail && apt update \
  && apt install -y --no-install-recommends build-essential curl git libpq-dev tzdata \
  && curl -sSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt update && apt install -y --no-install-recommends nodejs yarn \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
  && apt clean \
  && groupadd -g 1004 ruby \
  && useradd --create-home --no-log-init -u 1004 -g 1004 ruby \
  && chown ruby:ruby -R /app"

USER ruby

ARG RAILS_ENV="production"
ARG NODE_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    USER="ruby" \
    TZ="Asia/Kolkata"


# --- Optimized Dependency Installation ---

# 1. Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./
# 2. Install gems. This layer is only rebuilt if Gemfile.lock changes.
# RUN bundle install

# 3. Copy package.json and yarn.lock (or package-lock.json)
COPY package.json yarn.lock ./
# 4. Install node modules. This layer is only rebuilt if yarn.lock changes.
# RUN npm install

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
