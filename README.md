# Heroku buildpack: Redis Cloud SSL

This is a [Heroku buildpack](http://devcenter.heroku.com/articles/buildpacks) that
allows an application to use an [stunnel](http://stunnel.org) to connect securely to
Redis instances using client certificate authentication. It is meant to be used in conjunction with other buildpacks.

This buildpack contains only small changes from the base [Heroku Redis Buildpack](https://github.com/heroku/heroku-buildpack-redis)
* The goal of this fork is to make the changes necessary to provide a similar experience when using Redis services
  besides Heroku Redis, specifically [Redis Cloud](https://redislabs.com/redis-cloud).
* To use this buildback, you must have a plan that allows SSL to be enabled using stunnel and client certificates.

## Usage

First you need to set this buildpack as your initial buildpack with:

```console
$ heroku buildpacks:add -i 1 https://github.com/faros-ai/heroku-buildpack-redis-cloud.git
```

Then confirm you are using this buildpack as well as your language buildpack like so:

```console
$ heroku buildpacks
=== frozen-potato-95352 Buildpack URLs
1. https://github.com/faros-ai/heroku-buildpack-redis-cloud.git
2. heroku/python
```

For more information on using multiple buildpacks check out [this devcenter article](https://devcenter.heroku.com/articles/using-multiple-buildpacks-for-an-app).

### Enable SSL on your Redis resource
For Redis Cloud [follow the top part of these instructions](https://redislabs.com/kb/read-more-ssl) to enable ssl
* You will need a client certificate, private key, and CA cert to configure your app vars (see below)
* If migrating an existing production application from non-ssl to SSL, you may want to configure your app vars ahead of time
with `ENABLE_STUNNEL=false`, then push your new Procfile and switch `ENABLE_STUNNEL=true` at the moment you enable
SSL on the Redis resource. Redis Cloud does not allow instances to operate in mixed mode, so before you flip to SSL, be ready.

### Configuration

The buildpack will install and configure stunnel to connect to `REDIS_CLOUD_URL` by default. Prepend `bin/start-stunnel`
to any process in the Procfile to run stunnel alongside that process.

Some settings are configurable through app config vars at runtime:

- ``STUNNEL_CERT``: Paste in the client certificate to use for connecting to Redis Cloud. This is the same certificate
used when configuring the redis instance for SSL
- ``STUNNEL_KEY``: Paste in the private key for the client certificate. If you had Redis Cloud generate your cert, this key is in the zip file.
- ``STUNNEL_CA``: Paste in the certificate CA. If you had Redis Cloud generate the cert, this is also in the zip file provided.
- ``STUNNEL_ENABLED``: Defaults to `true`, set to `false` to disable stunnel.
- ``STUNNEL_FORCE_TLS``: Default is unset. Set this var, to force TLSv1 on cedar-10.
- ``REDIS_STUNNEL_URLS``: Use this to specify for which Redis URLs (environment variables) to activate the SSL tunnel.
For instance, ``$ heroku config:add REDIS_STUNNEL_URLS="CACHE_URL SESSION_STORE_URL"`` to specify two redis instances
with URLS set to `CACHE_URL` and `SESSION_STORE_URL` vars.

`STUNNEL_CERT`, `STUNNEL_KEY`, and `STUNNEL_CA` are required.

### Update your Procfile

For each process that should connect to Redis securely, you will need to preface the command in
your `Procfile` with `bin/start-stunnel`.

    $ cat Procfile
    web:    bin/start-stunnel bundle exec unicorn -p $PORT -c ./config/unicorn.rb -E $RACK_ENV
    worker: bin/start-stunnel bundle exec sidekiq

We're then ready to deploy to Heroku with an encrypted connection between the dynos and Redis:

    $ git push heroku master
    ...
    -----> Fetching custom git buildpack... done
    -----> Multipack app detected
    =====> Downloading Buildpack: https://github.com/faros-ai/heroku-buildpack-redis-cloud.git
    =====> Detected Framework: stunnel
           Using stunnel version: 5.02
           Using stack version: cedar
    -----> Fetching and vendoring stunnel into slug
    -----> Moving the configuration generation script into app/bin
    -----> Moving the start-stunnel script into app/bin
    -----> stunnel done
    =====> Downloading Buildpack: https://github.com/heroku/heroku-buildpack-ruby.git
    =====> Detected Framework: Ruby/Rack
    -----> Using Ruby version: ruby-2.2.2
    -----> Installing dependencies using Bundler version 1.7.12
    ...
    
### One-off dynos

Through an additional executable in this buildpack it is possible to run one-off dynos with secure Redis access.
Simply prepend `bin/run-stunnel` to all your one-off tasks and scheduled jobs, such as:

    $ heroku run bin/run-stunnel rails c
