function enqueue_request()
  local cjson = require "cjson"
  local redis = require "resty.redis"
  local r     = redis:new()
  local ok, err = r:connect(os.getenv("REDIS_URL"), os.getenv("REDIS_PORT"))
  if not ok then
    ngx.say(cjson.encode({status = "error", msg =  "failed to connect: " .. err}))
    return
  end

  ngx.req.read_body()

  local payload = {
    class = "Ping",
    args = { 
      headers = ngx.req.get_headers(),
      body = ngx.encode_base64(ngx.req.get_body_data()),
      uri = ngx.var.request_uri,
      method = ngx.var.request_method
    },
    retry = false,
    jid = 12345,
    created_at = ngx.now(),
    enqueued_at = ngx.now()
  }

  r:lpush("queue:default", cjson.encode(payload))
  -- ngx.req.read_body()
  -- ngx.say(cjson.encode({headers = ngx.req.get_headers(), body = ngx.req.get_body_data(), uri = ngx.var.request_uri}))
  ngx.say("<p>hello, world6666666</p>")
end
return enqueue_request;
