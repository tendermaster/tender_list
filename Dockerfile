FROM ruby:3.1.3

WORKDIR /app

ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y apt-transport-https

RUN bash -c "set -o pipefail && apt-get update \
  && apt-get install -y --no-install-recommends build-essential curl git libpq-dev tzdata \
  && curl -sSL https://deb.nodesource.com/setup_18.x | bash - \
  && curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo 'deb https://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs yarn \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
  && apt-get clean \
  && groupadd -g \"${GID}\" ruby \
  && useradd --create-home --no-log-init -u \"${UID}\" -g \"${GID}\" ruby \
  && chown ruby:ruby -R /app"

USER ruby

ARG RAILS_ENV="development"
ARG NODE_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    USER="ruby" \
    TZ="Asia/Kolkata"

# RUN bash -c "sudo apt-get install -y "

# ADD --chown=ruby:ruby Gemfile* ./
# ADD --chown=ruby:ruby package*.json ./

COPY package*.json ./
COPY Gemfile* ./

RUN bundle install
RUN npm install

# RUN bundle exec rails assets:precompile

# COPY --chown=ruby:ruby package.json *yarn* ./

EXPOSE 3000

# RUN chmod +x ./bin/init
#CMD ["rails", "s", "-b", "0.0.0.0"]
ENTRYPOINT ["bash", "./bin/init"]
