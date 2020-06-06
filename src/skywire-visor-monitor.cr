require "http/client"
require "log"
require "pool/connection"
require "rethinkdb"
require "tasker"

Log.builder.bind "*", Log::Severity.parse(ENV.fetch("CRYSTAL_LOG_LEVEL", "DEBUG")), Log::IOBackend.new

class Visor
  JSON.mapping(
    key: String,
    start_time: Int64
  )
end

alias Visors = Array(Visor)

DB_HOST          = ENV.fetch("APP_DB_HOST", "localhost")
DB_NAME          = ENV.fetch("APP_DB_NAME", "skywirevisor_development")
DB_PASSWORD      = ENV.fetch("APP_DB_PASSWORD", "skywirevisor_development")
DB_PORT          = ENV["APP_DB_PORT"]?.try(&.to_i32) || 28015
DB_TABLE_NAME    = ENV.fetch("APP_DB_TABLE_NAME", "visors_metrics")
DB_USER          = ENV.fetch("APP_DB_USER", "skywirevisor_development")
TICK_TIME_SECOND = (ENV["APP_TICK_TIME_SECOND"]?.try(&.to_i32) || 10).seconds
TRACKER_PATH     = ENV.fetch("APP_TRACKER_PATH", "/visors")
TRACKER_URI      = ENV.fetch("APP_TRACKER_URI", "https://uptime-tracker.skywire.skycoin.com")

class App
  include RethinkDB::Shortcuts

  Log = ::Log.for("App")

  @@rpool : ConnectionPool(RethinkDB::Connection) = ConnectionPool.new(capacity: 10, timeout: 1.0) do
    RethinkDB.connect(host: DB_HOST, port: DB_PORT, db: DB_NAME, user: DB_USER, password: DB_PASSWORD)
  end

  @@rpool.connection do |conn|
    begin
      RethinkDB.db(DB_NAME).table_create(DB_TABLE_NAME).run(conn) unless RethinkDB.db(DB_NAME).table_list.run(conn).as_a.includes?(DB_TABLE_NAME)
      RethinkDB.db(DB_NAME).table(DB_TABLE_NAME).index_create("timestamp_minute").run(conn) unless RethinkDB.db(DB_NAME).table(DB_TABLE_NAME).index_list.run(conn).as_a.includes?("timestamp_minute")
    rescue e : RethinkDB::ReqlRunTimeError
      Log.error(exception: e) { "#{e.message}" }
    rescue ue
      Log.error(exception: ue) { "#{ue.message}" }
    end
  end

  def run(now : Time)
    HTTP::Client.new(URI.parse(TRACKER_URI)) do |c|
      timeout = 10.seconds
      c.connect_timeout = timeout
      c.dns_timeout = timeout
      c.read_timeout = timeout
      c.write_timeout = timeout
      c.get(TRACKER_PATH) do |response|
        if response.status_code == 200
          json_str = response.body_io.gets
          if json_str && !json_str.strip.empty?
            write_stats(now, json_str)
          else
            Log.warn { "[run][HTTP RESPONSE]: empty!!" }
          end
        else
          Log.error { "[run][HTTP STATUS CODE]: #{response.status_code}" }
        end
      end
    end
  end

  def write_stats(now : Time, json_str : String)
    current_minute_ts = now.at_beginning_of_minute.to_unix
    visors = Visors.from_json(json_str)
    @@rpool.connection do |conn|
      if r.db(DB_NAME).table(DB_TABLE_NAME).filter({timestamp_minute: r.epoch_time(current_minute_ts),
                                                    type:             "num_of_visors"}).run(conn).size > 0
        r.db(DB_NAME).table(DB_TABLE_NAME).filter({timestamp_minute: r.epoch_time(current_minute_ts),
                                                   type:             "num_of_visors"}).update do |metrics|
          {
            num_samples:   metrics["num_samples"] + 1,
            total_samples: metrics["total_samples"] - metrics["values"]["#{now.second}"].default(0) + visors.size,
            values:        {
              "#{now.second}" => visors.size,
            },
          }
        end.run(conn)
      else
        r.db(DB_NAME).table(DB_TABLE_NAME).insert({
          name:             "skywire",
          timestamp_minute: r.epoch_time(current_minute_ts),
          type:             "num_of_visors",
          num_samples:      1,
          total_samples:    visors.size,
          values:           {
            "#{now.second}" => visors.size,
          },
        }).run(conn)
      end
    end
    Log.info { "[write_stats] - Number of visors: #{visors.size}" }
  end
end

Tasker.instance.every(TICK_TIME_SECOND) { spawn App.new.run(Time.utc) }

stoper = Channel(Nil).new(1)

Signal::INT.trap do
  Log.info { "Stoped !!" }
  stoper.send(nil)
end

Log.info { "Start !!" }
stoper.receive
