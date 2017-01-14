
FROM buildpack-deps:jessie

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 1.8
ENV RUBY_VERSION 1.8.7-p352
ENV RUBY_DOWNLOAD_SHA256 9df4e9108387f7d24a6ab8950984d0c0f8cdbc1dad63194e744f1a176d1c5576
ENV RUBYGEMS_VERSION 1.8.15

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	\
	&& buildDeps=' \
		bison \
		libgdbm-dev \
		ruby \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.bz2 "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.bz2" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.bz2" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xf ruby.tar.bz2 -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.bz2 \
	\
	&& cd /usr/src/ruby \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& export CFLAGS="-O2 -fno-tree-dce -fno-optimize-sibling-calls" \
	&& autoconf \
	&& ./configure --disable-install-doc --enable-shared \
	&& make -j"$(nproc)" \
	&& make install \
	\
	&& wget -O rubygems.tgz https://rubygems.org/rubygems/rubygems-$RUBYGEMS_VERSION.tgz \
	&& mkdir -p /usr/src/rubygems \
	&& tar -xf rubygems.tgz -C /usr/src/rubygems --strip-components=1 \
	&& cd /usr/src/rubygems \
	&& ruby setup.rb \
	\
	&& apt-get purge -y --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	&& rm -r /usr/src/rubygems \
	\
	&& gem update --system "$RUBYGEMS_VERSION"

ENV BUNDLER_VERSION 1.0.22

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

CMD [ "irb" ]
