--initializations
rj = require("rapidjson")
Controls.CurrentStream.String = ""
Controls.ManualStream.String = ""
--variables
v = {
  ip = Controls.IP,
  un = Controls.Username,
  pw = Controls.Password,
  fb = Controls.DeviceFB,
  auth = Controls.Authorized,
  stat = Controls.Status,
  rBtns = Controls.RouteButton
}
v.Url = 'https://'..v.ip.String..'/'
--functions
f = {
  dly = function(func, time)
    Timer.CallAfter(function() func() end, time) 
  end
}
--auth
auth = {
  header = {
    ["Content-Type"] = "application/json"
  },
  options = {
    Url = 'https://'..v.ip.String..'/userlogin.html',
    Method = 'POST',
    Headers = {["Content-Type"] = "application/json"},
    Data = 'login='..v.un.String..'&&passwd='..v.pw.String,
  },
  update = function(s)
    if not s then s = 2 end 
    if s == 1 then v.stat.Value = 5 end
    v.stat.Value = s
    v.auth.Value = s
  end,
  check = function(self, data)
    self.update(1)
    if not self.update(data:match("<!DOCTYPE html>")) then
      print("not authenticated")
      self.update(2)
      return false
    else
      self.update(0)
      return true
    end
  end,
  login = function(self)
    local cookieStr
    local response = function(t,c,d,e,h)
      auth:check(d)
      if c ~= 200 then print("Authentication error with code"..c) return false end
      if not h["Set-Cookie"] then print('missing auth cookie') return false end
      for k,v in pairs(h["Set-Cookie"]) do
        cookieStr = cookieStr..v
      end
      self.header["Cookie"]= cookieStr
    end
    self.options[EventHandler]= response
    HttpClient.Upload(options)
    --keepalive
    f.dly(self.login, 300)
  end
}
--tables
t = {
  Streams = {},
  FilteredStreams = {},
  Receivers = {},
  Get = {
    Url = v.Url,
    Headers = auth.header,
    Timeout = 10
  }
}
--functions called on runtime
init = {
  getStreams = function()
    local response = function(t,c,d,e,h)
      auth:check(d)
      if c ~= 200 then print("Authentication error with code: "..c) return false end
      for idx, stream in pairs(rj.decode(d).Device.DiscoveredStreams.Streams) do
        table.insert(t.Streams, {SessionName = stream.SessionName, Address = stream.Address:match("%d+%.%d+%.%d+%.%d+"), ID = idx, Type = "Encoder"})
      end
    end
    local options = t.Get
    options.Url = t.Get.Url.."Device/DiscoveredStreams"
    options.EventHandler = response
    HttpClient.Download(options)
  end
}
init.makeButtons = function()
  if #t.Streams == 0 then 
    init.getStreams()
    f.dly(function() print("attempting to initialize...") end, 1)
  else
    -- for idx, stream in pairs(t.Streams) do
    for idx, btn in pairs(v.rBtns) do
      btn.Legend = t.Streams[idx].SessionName or ""
    end
  end        
end

-- f.routeAV = function(route)
--   HttpClient.Upload {
--     Url = nvxBaseUrl.."Device/AvRouting/Routes",
--     Method = "POST", 
--     Data = [=[{"Device": {"AvRouting": {"Routes": [{"VideoSource": "]=]..route..[=["}]}}}]=],
--     Headers = authHeader,
--     EventHandler = function(t,c,d,e,h)
--       if c ~= 200 then print('Error with code: '..c) else
--         AuthCheck(d)
--         PollRoute()
--       end
--     end
--   }
-- end






----
function Init()
  for name, fn in pairs(init) do
    fn()
  end
end


Init()