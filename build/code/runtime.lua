-- init method
-- initialize NVX
-- login
-- get config
-- add functions


--initializations
rj = require("rapidjson")
C = Controls

--main object
N = {
  reInits = {
    IP = true,
    Username = true,
    Password = true
  }
}

function N:checkLogin(inputData)
  local doesNotReturnHtml = not inputData:match('<!DOCTYPE html>')
  return doesNotReturnHtml
end

--methods
--create and inheret N
function N:new(o)
  if not o then print "options needed to build utitilies" return false end
  o.Header = {["Content-Type"] = "application/json"}
  o.config = {}
  o.Urls = {
      base = 'https://'..o.ip..'/Device',
      login = 'https://'..o.ip..'/userlogin.html'
  }
  o.Authorized = false
  setmetatable(o, self)
  self.__index = self
  print('NVX instance created with ip address '..o.ip.."!")
  return o
end

--login
function N:login(o)
  o = o or {}
  --login the first time
  HttpClient.Upload({
    Url = self.Urls.login,
    Method = 'POST',
    Headers = self.Header,
    Data = 'login='..self.un..'&&passwd='..self.pw,
    EventHandler = function (t,c,d,e,h)
      self.Authorized = h["Set-Cookie"] and c == 200
      if c ~= 200 or not h["Set-Cookie"] then 
        -- if not o.externalUrl then self:authFb(false) end
        print('Authentication Error!:')
        print(e)
        return false 
      else
        local str = ""
        for _, s in pairs(h["Set-Cookie"]) do str = str..s end
        self.Header.Cookie = str
        if o.eh then 
          return o.eh(t,c,d,e,h) 
        end
      end
    end
  })
end

--get configuration data
function N:getConfigurationData(o)
  o = o or {}
  local url = o.snippet and self.Urls.base.."/"..o.snippet or self.Urls.base
  HttpClient.Download {
    Url = snippetUrl or url,
    Headers = self.Header,
    Timeout = o.timeout or 10,
    EventHandler = function(t,c,d,e,h)
      local successfullyLoggedIn = self:checkLogin(d)
      if not self.Authorized or not successfullyLoggedIn then 
        print(self.ip.." is not logged in") 
        return false 
      else
        if o.verbose then print('logged into '..self.Urls.base) end
      end
      if o.verbose then print(d) end
      if c ~= 200 then
        print("Error getting data from "..inputUrl.." with code: "..c..":")
        print(e) 
      else
        local encodedData = rj.decode(d)
        if not encodedData then print(self.Urls.base.." did not receive data") return false end
        -- print(rj.encode(encodedData,{pretty=true}))
        if o.snippet then
          -- print(o.snippet)
          -- print(rj.encode(self.config.Device[o.snippet], {pretty=true}))
          -- print(rj.encode(encodedData.Device, {pretty=true}))
          self.config.Device[o.snippet] = encodedData.Device
        else
          self.config = encodedData
        end
        if o.recursionTime then Timer.CallAfter(function() self:getData(url, o) end, o.recursionTime) end
        if o.eh then 
          return o.eh(t,c,d,e,h)
        else
          return encodedData
        end  
      end
    end
  }
end

--update preview window
function N:updatePreviewWindow(o)
  o = o or {}
  if not self.config then print('config file needs to be loaded to upload preview window') return false end
  local path = self.config.Device.Preview.ImageList.Image3.IPv4Path
  -- print(path)
  HttpClient.Download({
    Url = path,
    Headers = self.Header,
    Timeout = o.timeout or 10,
    EventHandler = function(t,c,d,e,h)
      C.PreviewImage.Style = rj.encode({
        DrawChrome = false,
        IconData = Crypto.Base64Encode(d),
        Legend = ''
      })
      if o.eh then o.eh(t,c,d,e,h) end
    end
  })
end

--save routes to system memory, location depends on whether live or emulating
function N:saveRouteToMemory(idx)
  local sIdx = tostring(idx)
  local sessionName = Controls.StreamName[idx].String
  local configData = self.externalStreams[sessionName]
  if not configData then
    error('no config data for stream')
  end
  self.savedRoutes[idx] = {
    SessionName = configData.SessionName,
    id = configData.id,
    MulticastAddress = configData.MulticastAddress,
    ip = configData.ip
  }
  local routesFile = io.open("design/savedRoutes.json", "w")
  if routesFile then
    routesFile:write(rj.encode(self.savedRoutes))
    routesFile:close()
  else
    print('cound not open file')
  end
end

--retrieves routes from saved memory
function N:retrieveSavedRoutes(o)
  o = o or {}
  local filePath = (function() if System.IsEmulating then return "design/savedRoutes.json" else return "media/savedRoutes.json" end end)()
  local routesFileCheck, routesFile
  if pcall(function()  assert(io.open(filePath, "r")) end) then 
    print('found file '..filePath..':')
    routesFileCheck = assert(io.open(filePath, "r"))
    routesFile = routesFileCheck:read("*all")
    self.savedRoutes = rj.decode(routesFile)
  else
    print('did not find file '..filePath..'...creating one')
    routesFileCheck = io.open(filePath, "w")
    self.savedRoutes = {}
  end
  routesFileCheck.close()
  if o.eh then return o.eh() else return routesFile end
end

function N:findCurrentStream()
  local routingTable = self.config.Device.AvRouting.Routes
  if #routingTable > 1 then print('multiple routes found, return first one') end
  local videoSource = routingTable[1].VideoSource
  for sessionName, data in pairs(self.externalStreams) do
    if videoSource == data.id then
      self.currentRoute = sessionName
      return data.id
    end
    self.currentRoute = false
    return false
  end
end

-- finish building stream environment
function N:buildStreamData()
  --populate discovered streams

  print('building stream data for '..self.ip)
  if not self.config.Device.DiscoveredStreams then print("gather discoveredStreams data first before populating streams list") return false end
  local streamsPulled = self.config.Device.DiscoveredStreams.Streams
  if streamsPulled == {} then print('no streams to acquire') return end

  self.externalStreams, self.dropdownList = {}, {}

  for uuid, data in pairs(streamsPulled) do
    data.id = uuid
    data.ip = data.Address:match("^https?://([^/]+)/onvif/services$".."")    
    data.Address = "https://"..data.ip --removes other address field
    data.un = self.un
    data.pw = self.pw
    local newInput = N:new(data)
    newInput:login({
      eh = function() 
        newInput:getConfigurationData()
      end
    })
    self.externalStreams[data.SessionName] = newInput
  end

  for uuid, data in pairs(streamsPulled) do
    table.insert(self.dropdownList, data.SessionName)
  end

  self:retrieveSavedRoutes({
    eh = function()
      for idx, ct in pairs(C.StreamName) do
        local sIdx = tostring(idx)
        self.savedRoutes = self.savedRoutes or {}
        if self.savedRoutes[idx] then
          ct.String = self.savedRoutes[idx].SessionName
        else
          ct.String = "" 
        end
        
        ct.Choices = self.dropdownList
        C["RouteButtons_1"][idx].Legend = "HDMI 1"
        C["RouteButtons_2"][idx].Legend = "HDMI 2"

        --preview button will assign preview
        C.AssignToPreview[idx].EventHandler = function(c)
          local newInput = self.externalStreams[ct.String]
          newInput:login({
            eh = function(t,c,d,e,h)
              newInput:updatePreviewWindow()
            end
          })
        end

        C["RouteButtons_1"][idx].EventHandler = function(c)
          if ct.String == "" then print('you must choose a stream before you can route') return false end
          local tx = self.externalStreams[ct.String]
          tx:switchInput(1, idx)
          local id = tx.id
          self:routeVideo(id)
        end

        C["RouteButtons_2"][idx].EventHandler = function(c)
          if ct.String == "" then print('you must choose a stream before you can route') return false end
          local tx = self.externalStreams[ct.String]
          tx:switchInput(2, idx)
          local id = tx.id
          self:routeVideo(id)
        end

        C.CopyStream[idx].Boolean = self.savedRoutes[idx]
        C.CopyStream[idx].EventHandler = function(c)
          self:saveRouteToMemory(idx)
        end

      end
    end
  })

  self:findCurrentStream()
  if self.currentRoute then 
    C.CurrentStream.Legend = "Stream: "..self.currentRoute
  else
    C.CurrentStream.Legend = "No Stream Routes"
  end
end

function N:postData(url, data, o)
  o = o or {
    eh = nil,
    verbose = nil,
    timeout = nil
  }
  HttpClient.Upload {
    Url = self.Urls.base..url,
    Method = "POST",
    Data = data,
    Headers = self.Header,
    Timeout = o.timeout or 10,
    EventHandler = function(t,c,d,e,h)
      if o.verbose then print(d) end
      if c ~= 200 then 
        print("Error getting device info with code: "..c..":")
        print(e) 
      else
        self:checkLogin(d)
        if not o.externalUrl then
          local encodedData = rj.decode(d)
          if not encodedData then print(url.." did not receive data") return false end
        end
        if o.recurse then Timer.CallAfter(function() self:getData(url, o) end, o.recursionTime or 20) end
        if o.eh then return o.eh(t,c,d,e,h) end  
      end
    end
  }
end


function N:routeVideo(uuid)
  local data = [=[{"Device": {"AvRouting": {"Routes": [{"VideoSource": "]=]..uuid..[=["}]}}}]=]
  self:postData("/Device/AvRouting/Routes", data, {
    verbose = true,
    eh = function(t,c,d,e,h)
      self:updatePreviewWindow()
    end
  })
end

function N:switchInput(channel, idx)
  local data = '{"Device": {"DeviceSpecific": {"VideoSource": "Input'..channel..'"}}}'
  self:postData("/Device/DeviceSpecific/VideoSource", data, {
    eh = function(t,c,d,e,h)
      self:updateActiveSource(idx)
      NVX:updatePreviewWindow()
    end
    -- eh = function() print(rj.encode(self.config.Device.DeviceSpecific, {pretty=true})) end
  })
end

function N:updateActiveSource(idx)
  self:getConfigurationData({
    -- snippet = "DeviceSpecific",
    eh = function()
      local activeVideoInput = tonumber(self.config.Device.DeviceSpecific.ActiveVideoSource:match("%d"))
      for i = 1, 2 do 
        Controls["RouteButtons_"..i][idx].Value = i ==activeVideoInput and 1 or 0 
      end
    end
  })
  
end


function N:Init()

  if System.IsEmulating then
    print('System is Emulating with IP address '..Network.Interfaces()[1].Address)
  end

  NVX = N:new({
    ip = C.IP.String,
    un = C.Username.String,
    pw = C.Password.String
  })
  
  NVX:login({
    eh = function()
      local x = NVX:getConfigurationData({
        eh = function() 
          NVX:updatePreviewWindow()
          NVX:buildStreamData()
        end
      })
    end
  })

  for name, boolean in pairs(N.reInits) do C[name].EventHandler = function() N:Init() end end
end

-- for k,v in pairs(dir.get("design/")) do print(rj.encode(v)) end


N:Init()

return NVX

--old code before refactoring

-- --updates preview pane with this nvx, or a different one, depending on optoins
-- function N:updatePreviewWindow(o)
--   o = o or {}
--   local function turnPathIntoPreview(path)
--     self:getData('', {
--       externalUrl = path,
--       eh = function (t,c,d,e,h)
--         C.PreviewImage.Style = rj.encode({
--           DrawChrome = false,
--           IconData = Crypto.Base64Encode(d),
--           Legend = ''
--         })
--       end
--     })
--   end
--   if o.externalUrl then -- for a device other than this one
--     self:getData('', {
--       externalUrl = o.externalUrl.."/Device/Preview",
--       eh = function(t,c,d,e,h)
--         if e then print(e) end 
--         turnPathIntoPreview(rj.decode(d).Device.Preview.ImageList.Image3.IPv4Path)
--       end
--     })
--   else
--     if not self.config.Device.Preview then print("gather preview data first before updating preview window") return false end
--     turnPathIntoPreview(self.config.Device.Preview.ImageList.Image3.IPv4Path)
--   end
-- end


-- function N:postData(url, data, o)
--   o = o or {
--     eh = nil,
--     verbose = nil,
--     timeout = nil
--   }
--   HttpClient.Upload {
--     Url = self.Urls.base..url,
--     Method = "POST",
--     Data = data,
--     Headers = self.Header,
--     Timeout = o.timeout or 10,
--     EventHandler = function(t,c,d,e,h)
--       if o.verbose then print(d) end
--       if c ~= 200 then 
--         print("Error getting device info with code: "..c..":")
--         print(e) 
--       else
--         self:checkLogin(d)
--         if not o.externalUrl then
--           local encodedData = rj.decode(d)
--           if not encodedData then print(url.." did not receive data") return false end
--           self.config[url] = encodedData["Device"][url]
--         end
--         if o.recurse then Timer.CallAfter(function() self:getData(url, o) end, o.recursionTime or 20) end
--         if o.eh then return o.eh(t,c,d,e,h) end  
--       end
--     end
--   }
-- end

-- function N:getConfig(o)
--   o = o or {}
--   self:getData('/Device', {
--     eh = function(t,c,d,e,h)
--       self.deviceType = self.config.Device.DeviceSpecific.DeviceMode
--       if o.eh then o.eh() end
--       if self.deviceType == "Receiver" then
--         self:updatePreviewWindow()
--         self:buildStreamData()
--       elseif self.deviceType == "Transmitter" then
--         local p = self.config.Device.StreamTransmit.Streams
--         -- print(rj.encode(self.config.Device.StreamTransmit.Streams), {pretty=true})
--         -- for k,v in pairs(p) do print(v.UUID) end
--         -- self:toggleAutoRouting(false, {
--         --   eh = function() self:switchInput("2") end
--         -- })
--       end
--     end
--   })
-- end



  -- --add data for each new device
  -- function N:buildUtilities(o)
    -- if not o then print "options needed to build utitilies" return false end
    -- self.Header = {["Content-Type"] = "application/json"}
    -- self.ip = o.ip
    -- self.un = o.un
    -- self.pw = o.pw
    -- self.config = {}
    -- self.Urls = {
    --   base = 'https://'..self.ip,
    --   login = 'https://'..self.ip..'/userlogin.html',
    -- }
    -- function self:updateCli(data)
    --   if not data then return false end

    -- end
    -- function self:clearCli() cli = "" end
    -- function N:printConfig()
    --   print(rj.encode(self.config.Device, {pretty=true}))
    -- end
    -- self.credsEntered = self.un ~= "" and self.pw ~= ""
    -- function self:authFb(s)
    --   local a = C.Authorized
    --   if not s then print("<err: NVX is not Authorized!!>") end
    --   a.Color = s and "Green" or "Red"
    --   a.Legend = s and "Authorized" or "NOT Authorized"
    --   self.Authorized = s
    --   -- self:setControls(function(c) c.IsIndeterminate = not s end)
    -- end

    -- function self:checkLogin(inputData)
    --   local doesNotReturnHtml = not inputData:match('<!DOCTYPE html>')
    --   return doesNotReturnHtml
    -- end 

    -- function N:deviceModeFb()
    --   C.DeviceMode.Color = self.deviceType == "Transmitter" and "Cyan" or "Magenta"
    --   C.DeviceMode.String = self.deviceType
    -- end

    -- if not o.external then
    --   for hdmi = 1, 2 do C["HdmiInput"][hdmi].Legend = "HDMI "..hdmi end
    --   -- self.cli = C.CLI
    --   -- self.cli.String = ""
    --   -- if N.cli.String == "" then N.cli.String = data return true end
    --   -- N.cli.String = N.cli.String.."\n"..data
    --   -- function self:checkLogin(inputData)
    --   --   local returnsHtml = inputData:match('<!DOCTYPE html>')
    --   --   if (returnsHtml) then
    --   --     print("login failed for "..self.ip)
    --   --     local a = C.Authorized
    --   --     a.Color = "Yellow"
    --   --     a.Legend = "<!err>"
    --       return false
    --     else
    --       self:authFb(self.Authorized)
    --       return true
    --     end
    --   end
    -- end
    -- print('Utitlities created for '..self.ip.." with base of "..self.Urls.base)
  -- end

  -- --update status icon
  -- function N:updateStatusIcon()

  -- end



  -- --generic function to get data
  -- function N:getData(url, o)
  --   o = o or {
  --     eh = nil,
  --     externalUrl = nil,
  --     verbose = nil,
  --     timeout = nil,
  --     recursionTime = nil
  --   }
  --   local inputUrl = o.externalUrl or self.Urls.base..url

  --   HttpClient.Download {
  --     Url = inputUrl,
  --     Headers = self.Header,
  --     Timeout = o.timeout or 10,
  --     EventHandler = function(t,c,d,e,h)
  --       -- self:checkLogin(d)
  --       if o.verbose then print(d) end
  --       if c ~= 200 then
  --         print("Error getting data from "..inputUrl.." with code: "..c..":")
  --         print(e) 
  --       else
  --         if not o.externalUrl then
  --           -- self:checkLogin(d)
  --           local encodedData = rj.decode(d)
  --           if not encodedData then print(inputUrl.." did not receive data") return false end
  --           if url:match("^/Device/%w+") then
  --             self.config[url] = encodedData["Device"][url]
  --           else
  --             self.config = encodedData
  --           end
  --         end
  --         if o.recursionTime then Timer.CallAfter(function() self:getData(url, o) end, o.recursionTime) end
  --         if o.eh then 
  --           return o.eh(t,c,d,e,h)
  --         else
  --           return encodedData
  --         end  
  --       end
  --     end
  --   }
  -- end


  -- function N:routeVideo(uuid)
  --   local data = [=[{"Device": {"AvRouting": {"Routes": [{"VideoSource": "]=]..uuid..[=["}]}}}]=]
  --   self:postData("/Device/AvRouting/Routes", data, {
  --     verbose = true
  --   })
  -- end

  -- function N:toggleAutoRouting(s, o)
  --   o = o or {}
  --   local inputData = '{"Device": {"DeviceSpecific": {"AutoInputRoutingEnabled": '..tostring(s)..'}}}'
  --   self:postData("/Device/DeviceSpecific/VideoSource", inputData, {
  --     eh = o.eh or false
  --   })
  -- end



  -- -- builds list of streams and populates table
  -- function N:buildStreamData()

  --   if not self.config.Device.DiscoveredStreams then print("gather discoveredStreams data first before populating streams list") return false end
  --   local streamsPulled = self.config.Device.DiscoveredStreams.Streams
  --   if streamsPulled == {} then print('no streams to acquire') return end

  --   self.externalStreams, self.dropdownList = {}, {}

  --   for uuid, data in pairs(streamsPulled) do
  --     data.id = uuid
  --     data.ip = data.Address:match("^https?://([^/]+)/onvif/services$".."")    
  --     data.Address = "https://"..data.ip --removes other address field
  --     data.un = self.un
  --     data.pw = self.pw
  --     local newInput = N:new(data)
  --     newInput:buildUtilities({
  --       ip = data.ip,
  --       un = data.un,
  --       pw = data.pw,
  --       external = true
  --     })
  --     newInput:login({
  --       eh = function() 
  --         newInput:getConfig({}) 
  --       end
  --     })
  --     self.externalStreams[data.SessionName] = newInput
  --   end

  --   for uuid, data in pairs(streamsPulled) do
  --     table.insert(self.dropdownList, data.SessionName)
  --   end

  --   self:retrieveSavedRoutes({
  --     eh = function()

  --       for idx, ct in pairs(C.StreamName) do
  --         local sIdx = tostring(idx)
  --         self.savedRoutes = self.savedRoutes or {}
  --         if self.savedRoutes[idx] then
  --           ct.String = self.savedRoutes[idx].SessionName
  --         else
  --           ct.String = "" 
  --         end
          
  --         ct.Choices = self.dropdownList
  --         C.AssignToPreview[idx].EventHandler = function(c)
  --           local newInput = self.externalStreams[ct.String]
  --           newInput:login({
  --             eh = function(t,c,d,e,h)
  --               newInput:updatePreviewWindow()
  --             end
  --           })
  --         end

  --         C.RouteButtons[idx].EventHandler = function(c)
  --           if not ct.String then print('you must choose a stream before you can route') end
  --           local id = self.externalStreams[ct.String].id
  --           self:routeVideo(id)
  --         end

  --         C.CopyStream[idx].Boolean = self.savedRoutes[idx]
  --         C.CopyStream[idx].EventHandler = function(c)
  --           self:saveRouteToMemory(idx)
  --         end
  --       end
  --     end
  --   })

  --   self:findCurrentStream()

  --   C.CurrentStream.Legend = "Stream ("..self.config.Device.DeviceSpecific.VideoSource..")"
  -- end
