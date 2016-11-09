if string.lower(ngx.var.uri) ~= "/your path" then
    return
end

require 'config'
local redis = require "redis"
local redis_ip = REDIS_IP
local redis_port = REDIS_PORT
local redis_timeout = REDIS_TIMEOUT
local redis_keepalive_time = REDIS_KEEPALIVE_TIME
local redis_pool_size = REDIS_POOL_SIZE
local max_request_cnt = MAX_REQUEST_CNT

local red = redis:new()
red:set_timeout(redis_timeout)
local ok, err = red:connect(redis_ip, redis_port)
if not ok then
    ngx.log(ngx.ERR, err)
    return
end

-- 每个ip请求次数的前缀，目前以五分钟为一个维度
local prefix = math.ceil(os.date("%M") / 5)
-- 获取request的ip地址
local ip = ngx.var.remote_addr
if not ip then
    ngx.log(ngx.ERR, "can not get remote_addr")
    return
end
-- 缓存每五分钟请求次数的键名
local ipLimitKey = prefix .. ip
local field, err = red:get(ipLimitKey)
if err ~= nil then
    ngx.log(ngx.ERR, err)
    return                                                                                                                                                                                              
end
if tonumber(field) ~= nil and tonumber(field) > max_request_cnt then
    ngx.exit(ngx.HTTP_FORBIDDEN)
end
red:init_pipeline()
red:incr(ipLimitKey)
red:expire(ipLimitKey, 300)
local result, err = red:commit_pipeline()
if not result then
    ngx.log(ngx.ERR, "error:", err)
end

local limitCnt, err = red:get(ipLimitKey)

local ok, err = red:set_keepalive(redis_keepalive_time, redis_pool_size)
-- ngx.log(ngx.ERR, ok)
if not ok then
    ngx.log(ngx.ERR, "failed to set keepalive: ", err)
    return
end

if tonumber(limitCnt) ~= nil and tonumber(limitCnt) > max_request_cnt then
     ngx.exit(ngx.HTTP_FORBIDDEN)
end



