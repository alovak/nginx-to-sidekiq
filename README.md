# Nginx (OpenResty) module to use Sidekiq as a backend

This is POC (Proof of concept)! My idea was to use handle http requests with sidekiq worker
to avoid the need of web servers like Puma or Unicorn.

# Usage

First, you need Docker on your machine. To download and run necessary services (Redis, OpenResty):

```
docker-compose up
```

It will run Redis and Nginx on port 80. You can make requests using curl:

```
curl http://localhost/whatever -d "param=value"
```

Request will be serialized by lua script and pushed into Sidekiq queue for processing.

# Sidekiq

Please, create new (or use your existing) [Sidekiq](https://github.com/mperham/sidekiq/) project. All http
requests should be processed by ```ProxyWorker::Worker``` Sidekiq Worker. Here is an example of how it may look like:

```ruby
class ProxyWorker::Worker
  include Sidekiq::Worker

  def perform(params)
    # using params you can build Rack::Request
    request = build_request(params)

    # notify nginx that request was handled
    # send back response via redis
    $redis.with do |redis|
      redis.set(params['request_id'], JSON.dump(response_params))
      redis.publish(params['request_id'], 'done')
    end
  end
end
```

