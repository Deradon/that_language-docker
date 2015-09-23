FROM gliderlabs/alpine:edge
MAINTAINER Patrick Helm <me@patrick-helm.de>

# Set ENV
ENV BUILD_PACKAGES build-base gcc make git
ENV RUBY_PACKAGES ruby ruby-io-console ruby-dev ruby-bundler ruby-json
ENV RUBY_GEMS thin sinatra rake
ENV RACK_ENV production

# RUN
RUN apk update && \
    apk upgrade && \
    apk add $BUILD_PACKAGES && \
    apk add $RUBY_PACKAGES && \
    gem install --no-ri --no-rdoc $RUBY_GEMS && \
    rm -rf /var/cache/apk/* && \
    rm -rf /usr/share/ri

RUN mkdir /usr/app
WORKDIR /usr/app

COPY . /usr/app

RUN  bundle install \
     --jobs=4

EXPOSE 4567
CMD bundle exec rackup -p 4567
# CMD ["./service"]
