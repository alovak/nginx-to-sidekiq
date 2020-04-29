function enqueue_request()
  local random = require "resty.random"
  local cjson = require "cjson"
  local redis = require "resty.redis"
  local r_sidekiq = redis:new()
  local r_queue = redis:new()

  local ok, err = r_sidekiq:connect(os.getenv("REDIS_URL"), os.getenv("REDIS_PORT"))
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(cjson.encode({status = "error", msg =  "failed to connect: " .. err}))
    return
  end

  local ok, err = r_queue:connect(os.getenv("REDIS_URL"), os.getenv("REDIS_PORT"))
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(cjson.encode({status = "error", msg =  "failed to connect: " .. err}))
    return
  end

  local request_id = random.token(12)

  ok, err = r_queue:subscribe(request_id)
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say("failed to subscribe: ", err)
    return
  end

  ngx.req.read_body()
  local payload = {
    class = "ProxyWorker::Worker",
    args = { 
      headers = ngx.req.get_headers(),
      body = ngx.encode_base64(ngx.req.get_body_data()),
      uri = ngx.var.request_uri,
      method = ngx.var.request_method
    },
    retry = false,
    jid = request_id,
    created_at = ngx.now(),
    enqueued_at = ngx.now()
  }

  r_sidekiq:lpush("queue:default", cjson.encode(payload))

  -- wait for sidekiq task to complete
  ok, err = r_queue:read_reply()
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say("failed to read reply: ", err)
    return
  end

  -- load response payload
  local response_payload, err = r_sidekiq:get(request_id)
  if not response_payload then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say("failed to read payload: ", err)
    return
  end

  -- respond to client
  local resp = cjson.decode(response_payload)
  ngx.status = resp["status"]
  for key, val in pairs(resp.headers) do
    ngx.header[key] = val
  end
  ngx.say(ngx.decode_base64(resp["body"]))

  r_queue:close()
  r_sidekiq:close()
end
return enqueue_request;
