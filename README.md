# Skywire Visor Monitor

This program store the number of available Skywire visors in world over the time.

## Installation

You have to install crystal for your operating system: https://crystal-lang.org/docs/installation/

## Set environment variables

    export APP_DB_HOST=localhost
    export APP_DB_NAME=skywirevisor_development
    export APP_DB_PASSWORD=skywirevisor_development
    export APP_DB_PORT=28015
    export APP_DB_TABLE_NAME=visors_metrics
    export APP_DB_USER=skywirevisor_development
    export APP_TICK_TIME_SECOND=10
    export APP_TRACKER_PATH="/visors"
    export APP_TRACKER_URI="https://uptime-tracker.skywire.skycoin.com"

## Usage

    shards build --production

## Development

### Launch RethinkDB administration tool

First of all, you need a RethinkDB datastore: https://rethinkdb.com/docs/install/.

You can deploy an instance on cloud provider like AWS or Compose: https://rethinkdb.com/docs/paas/

1. With *docker*

    __replace *rethinkdb* by your docker instance name__

        xdg-open "http://$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' rethinkdb):8080"

2. With a local RethinkDB instance

        xdg-open "http://localhost:8080"

3. With a remote instance of RethinkDB

        xdg-open "https://my.domain.com:8080"

### Configure the database

    r.db('rethinkdb').table('users').insert({id: 'skywirevisor_development', password: 'skywirevisor_development'});
    r.dbCreate('skywirevisor_development');
    r.db('skywirevisor_development').grant('skywirevisor_development', {read: true, write: true, config: true});

## Contributing

1. Fork it (<https://github.com/fenicks/skywire-visor-monitor/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [fenicks](https://github.com/fenicks) Christian Kakesa - creator, maintainer
