local redis = require "redis"
 
local M = {}
 
 
local function set_keepalive(p,red,opts)
    while true do
        if 'dead' == coroutine.status(p) then
            break
        end
        ngx.sleep(0.01)
    end
 
    local ok,err = red:set_keepalive(opts.freetime,opts.poolsize)
    if not ok then
        ngx.log(ngx.ERR,"Failed to set keepalive: ",err)
        return
    end
end
 
function M:new(opts)
    opts = opts or {}
    opts.ip = opts.ip or '127.0.0.1'
    opts.port = opts.port or 6379
    opts.auth = opts.auth or ''
    opts.db = opts.db or 0
    opts.timeout = opts.timeout or 1000
    opts.poolsize = opts.poolsize or 100 -- 连接池大小 100 个
    opts.freetime = opts.freetime or 10 * 1000 -- 最大空闲时间 10s
 
    local red = redis:new()
    red:set_timeout(opts.timeout)
 
    local ok,err = red:connect(opts.ip,opts.port)
    if not ok then
        ngx.log(ngx.ERR,"Failed to connect redis: ",err)
        return ok,err
    end

    if opts.auth ~= '' then
        red:auth(opts.auth)
    end

    -- local count,err = red:get_reused_times()
    -- ngx.log(ngx.ERR,"redis get_reused_times: ",count)

 
    local ok,err = red:select(opts.db)
    if not ok then
        ngx.log(ngx.ERR,"Failed to select redis db: ",err)
    end

    local t,err = ngx.thread.spawn(set_keepalive,coroutine.running(),red,opts)
    if not t then
        ngx.log(ngx.ERR,"Failed to spawn thread set_keepalive: ",err)
        return t,err
    end
 
    return red
end
 
return M
