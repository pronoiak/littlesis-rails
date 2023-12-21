FROM docker.io/library/ruby:3.2.2-bookworm
LABEL maintainer="dev@littlesis.org"
ARG RAILS_ENV=$RAILS_ENV

RUN apt-get update && apt-get upgrade -y && apt-get -y --no-install-recommends install \
    build-essential coreutils curl git grep gzip postgresql-client rclone rsync sqlite3 unzip zip zstd brotli imagemagick redis-tools \
    nodejs npm \
    libmagickwand-dev libpq-dev libsqlite3-dev libpng-dev libsodium-dev libmariadbd-dev

# maticore
RUN curl "https://repo.manticoresearch.com/manticore-repo.noarch.deb" >  /tmp/manticore-repo.noarch.deb  && dpkg -i /tmp/manticore-repo.noarch.deb && apt-get update
RUN apt-get -y install manticore || apt-get -y install manticore

# firefox-esr, chromium
RUN if [ $RAILS_ENV = "development" ]; then \
    apt-get -y --no-install-recommends install firefox-esr chromium; fi

# install firefox-beta, geckodriver, chromium
RUN if [ $RAILS_ENV = "development" ]; then \
    curl "https://packages.mozilla.org/apt/repo-signing-key.gpg" -o /etc/apt/keyrings/packages.mozilla.org.asc \
    && gpg --show-key /etc/apt/keyrings/packages.mozilla.org.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list \
    && apt-get update && apt-get install -y firefox-beta \
    && curl -L "https://github.com/mozilla/geckodriver/releases/download/v0.33.0/geckodriver-v0.33.0-linux64.tar.gz" | tar xzf - -C /usr/local/bin \
    ; fi


RUN useradd --home /littlesis -s /bin/bash -u 1000 littlesis
USER littlesis
WORKDIR /littlesis
EXPOSE 8080
CMD /littlesis/bin/puma
# docker compose run app bundle config --global path vendor/bundle

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN if [ $RAILS_ENV = "production" ]; then \
#     bundle config --global frozen 1; fi

# COPY /Gemfile.lock ./Gemfile ./
# RUN bundle install

# # ensure package-lock in production
# RUN if [ $RAILS_ENV = "production" ]; then \
#     npm config set package-lock-only 'true'; fi

# COPY ./package.json ./package-lock.json ./
# RUN npm ci
