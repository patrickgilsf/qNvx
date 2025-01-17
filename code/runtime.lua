--initializations
rj = require("rapidjson")
require("json")
C = Controls

--main object
N = {}

--methods
--create and inheret N
function N:new(o)
  if not o then print "Can't initialize without options" return false end
  o.Header = {["Content-Type"] = "application/json"}
  o.config = {}
  o.Urls = {
      base = 'https://'..o.ip..'/Device',
      login = 'https://'..o.ip..'/userlogin.html'
  }
  o.StateTriggers = {
    [0] = {
      Color = "Grey"
    },
    [1] = {
      Color = "White"
    }
  }
  o.AuthFeedback = {
    [0] = {
      Color = "Red",
      String = "<<Auth Error!>>"
    },
    [1] = {
      Color = "Green",
      String = "Authorized"
    }
  }
  o.Authorized = false
  --these controls will re-initalize
  o.reInits = {
    IP = true,
    Username = true,
    Password = true
  }
  setmetatable(o, self)
  self.__index = self
  print('NVX instance created with ip address '..o.ip.."!")
  return o
end

function N:authFb(s)
  self:updateAccordingToValue(C.AuthStatus, "AuthFeedback", s and 1 or 0)
  C.Status.Value = s and 0 or 2
end 

function N:authFlow(inputData, fn)
  self.Authorized = not inputData:match('<!DOCTYPE html>')
  self:authFb(NVX.Authorized)
  if not self.Authorized then 
    self:login({
      eh = fn
    })
    -- return fn() 
  else 
    return self.Authorized 
  end
end

--update a button according to value
function N:updateAccordingToValue(control, tbl, inputValue)
  for prop, val in pairs(self[tbl][inputValue]) do control[prop] = val end
end

--print system config, full or partial
function N:printConfig(subPath)
  local path
  if subPath then path = self.config.Device[subPath] else path = self.config.Device end
  print(rj.encode(path, {pretty=true}))
end

--get type ("Transmitter or Receiver")
function N:updateDeviceType()
  if not self.config.Device.DeviceSpecific then print("no device specific data") return false end
  local type = self.config.Device.DeviceSpecific.DeviceMode
  self.deviceMode = type --shorthand
  return type
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
        local concat = self.SessionName or self.ip
        print('Authentication Error with '..concat..'!')
        self:authFb()
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
  local url = o.subPath and self.Urls.base.."/"..o.subPath or self.Urls.base
  if o.subPath then print('subPath: '..o.subPath) end
  HttpClient.Download {
    Url = url,
    Headers = self.Header,
    Timeout = o.timeout or 10,
    EventHandler = function(t,c,d,e,h)
      self:authFlow(d, function() self:getConfigurationData(o) end)
      if not self.Authorized then 
        print(self.ip.." is not logged in") 
      else
        if o.verbose then print('logged into '..self.Urls.base) end
      end
      if o.verbose then print(d) end
      if c ~= 200 then
        print("Error getting data from "..url.." with code: "..c..":")
        print(e) 
      else
        local encodedData = rj.decode(d)
        if not encodedData then print(self.Urls.base.." did not receive data") return false end
        if o.subPath then
          self.config.Device[o.subPath] = encodedData["Device"][o.subPath]
        else
          self.config = encodedData
        end
        if o.eh then 
          return o.eh(t,c,d,e,h)
        else
          return encodedData
        end  
      end
    end
  }
end

--sends post request to device
function N:postData(url, data, o)
  o = o or {
    eh = nil,
    verbose = nil,
    timeout = nil
  }
  local inputUrl = self.Urls.base..url
  HttpClient.Upload {
    Url = inputUrl,
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
        self:authFlow(d, function() self:postData(url, data, o) end)
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

--update system information in system window
function N:updateSystemInfo()
  local subPath = self.config.Device.DeviceInfo
  local sysInfo = {
    subPath.Model,
    subPath.MacAddress,
    subPath.SerialNumber
  }
  for index, control in pairs(C.SysInfo) do
    control.String = sysInfo[index]
  end
end

--updates polling for buttons between stream, hdmi 1 and hdmi 2 (decoder) and hdmi 1 and hdmi 2 (encoder)
function N:pollActiveSource(o)
  o = o or {}
  if not self.config.Device then print('cannot poll active source without config file loaded') return false end
  print('updating '..self.ip..' to video source: '..self.config.Device.DeviceSpecific.ActiveVideoSource)
  self.activeVideoInput = self.config.Device.DeviceSpecific.ActiveVideoSource
  if self.deviceMode == "Receiver" then
    self.routesControls = {
      ["CurrentStreamName"] = "Stream",
      ["CurrentRouteButton_1"] = "Input1",
      ["CurrentRouteButton_2"] = "Input2"
    }
  elseif self.deviceMode == "Transmitter" then
    if not o.idx then print('index needed to update polling for '..self.SessionName) return false end
    self.routesControls = {
      ["RouteButton_1"] = "Input1",
      ["RouteButton_2"] = "Input2"
    }
  end
  for controlName, source in pairs(self.routesControls) do
    local control
    if o.idx then control = C[controlName][o.idx] else control = C[controlName] end
    control.Value = source == self.activeVideoInput and 1 or 0
    -- control.Value = source == self.config.Device.DeviceSpecific.AcVideoSource and 1 or 0
    self:updateAccordingToValue(control, "StateTriggers", control.Value)
  end
end

--find stream and route, update buttons
function N:updateDecoderValues()
  self:pollActiveSource()

  --route
  local routingTable = self.config.Device.AvRouting.Routes
  if #routingTable > 1 then print('multiple routes found, return first one') end
  self.route = routingTable[1].VideoSource
  for sessionName, data in pairs(self.externalStreams) do
    if self.route == data.id then
      self.currentStream = sessionName
      C.CurrentStreamName.Legend = "Stream: "..self.currentStream
      return data.id
    end
  end
  C.CurrentStream.Legend = "No Stream Routes"
  self.currentStream = false
  return false

end

--switch input
function N:switchInput(input, idx)
  local data = '{"Device": {"DeviceSpecific": {"VideoSource": "'..input..'"}}}'
  self:postData("/DeviceSpecific/VideoSource", data, {
    eh = function(t,c,d,e,h)
      self:getConfigurationData({
        eh = function()
          if idx then
            self:pollActiveSource({idx = idx}) 
          else 
            self:pollActiveSource() 
          end
        end
      })
      NVX:updatePreviewWindow()
    end
  })
end

--route video from streams, according to uuid
function N:routeFromStream(uuid)
  -- self:switchInput("Stream")
  local data = [=[{"Device": {"AvRouting": {"Routes": [{"VideoSource": "]=]..uuid..[=["}]}}}]=]
  self:postData("/AvRouting/Routes", data, {
    eh = function(t,c,d,e,h)
      -- NVX:updatePreviewWindow()
    end
  })
  self:getConfigurationData({
    eh = function(t,c,d,e,h)
      self:updateDecoderValues()
    end
  })
end

--update state triggers for preview
function N:pollPreviewButtons(o)
  o = o or {}
  -- C.CurrentPreview.Value = o.idx and 0 or 1
  self:updateAccordingToValue(C.CurrentPreview, "StateTriggers", o.idx and 0 or 1)
  for idx, ctl in pairs(C.AssignToPreview) do
    if o.idx then 
      self:updateAccordingToValue(ctl, "StateTriggers", o.idx == idx and 1 or 0)
    else
      self:updateAccordingToValue(ctl, "StateTriggers", 0)
    end
  end
end
function N:assignPreviewToWindow(o)
  o = o or {}
  local path = self.config.Device.Preview.ImageList.Image3.IPv4Path
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
      if o.eh then o.eh(t2,c2,d2,e2,h2) end
      self:pollPreviewButtons({idx = o.idx})
    end
  })
end
--update preview window
function N:updatePreviewWindow(o)
  print('updating preview window')
  NVX.mostRecentPreview = self.id
  o = o or {}
  if not self.config then print('config file needs to be loaded to upload preview window') return false end
  self:getConfigurationData({
    subPath = "Preview",
    eh = function()
      self:assignPreviewToWindow(o)
    end
  })
  --recursion
  if self.id == NVX.mostRecentPreview then
    print('updating preview window')
    Timer.CallAfter(function()
      self:getConfigurationData({
        eh = function()
          self:assignPreviewToWindow(o)
        end
      })
    end, 5)
  end
end

--save routes to system memory, location depends on whether live or emulating
function N:saveRouteToMemory(idx)
  local sIdx = tostring(idx)
  local sessionName = C.StreamName[idx].String
  local configData = self.externalStreams[sessionName]
  if not configData then
    print("You can't save a route with selecting from the dropdown box first ")
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
    C.CopyStream[idx].Value = 1
  else
    print('cound not open file')
  end
end

--retrieves routes from saved memory
function N:retrieveSavedRoutesFromMemory(o)
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

-- finish building stream environment
function N:buildDecoder()

  self:updateSystemInfo()

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
    local states = {

    }
    newInput:login({
      eh = function() 
        newInput:getConfigurationData({
          eh = function()
            newInput:updateDeviceType()
          end
        })
      end
    })

    self.externalStreams[data.SessionName] = newInput
  end

  for uuid, data in pairs(streamsPulled) do
    table.insert(self.dropdownList, data.SessionName)
  end

  self:retrieveSavedRoutesFromMemory({
    eh = function()
      for idx, ct in pairs(C.StreamName) do
        local sIdx = tostring(idx)
        self.savedRoutes = self.savedRoutes or {}
        if self.savedRoutes[idx] then
          ct.String = self.savedRoutes[idx].SessionName
          --add timer to wait for getConfigurationData()
          Timer.CallAfter(function() self.externalStreams[ct.String]:pollActiveSource({idx = idx}) end, 5 )
        else
          ct.String = "" 
        end
        
        ct.Choices = self.dropdownList

        --preview button will assign preview
        C.AssignToPreview[idx].EventHandler = function(c)
          local newInput = self.externalStreams[ct.String]
          newInput:login({
            eh = function(t,c,d,e,h)
              newInput:updatePreviewWindow({idx = idx})
            end
          })
        end

        --set encoder's routing buttons
        for hdmiIdx = 1, 2 do
          local btn = C["RouteButton_"..hdmiIdx][idx]
          btn.Legend = "HDMI "..hdmiIdx
          btn.EventHandler = function(c)
            if ct.String == "" then print('you must choose a stream before you can route') return false end
            local tx = self.externalStreams[ct.String]
            tx:switchInput("Input"..hdmiIdx, idx)
            local id = tx.id
            self:routeFromStream(id)
          end
        end

        C.CopyStream[idx].Boolean = self.savedRoutes[idx]
        C.CopyStream[idx].EventHandler = function(c)
          self:saveRouteToMemory(idx)
        end

      end
    end
  })

  self:updateDecoderValues()
  
  C.CurrentStreamName.EventHandler = function(c)
    self:switchInput("Stream")
  end

  for hdmi = 1, 2 do 
    local btn = C["CurrentRouteButton_"..hdmi]
    btn.Legend = "HDMI "..hdmi
    btn.EventHandler = function(c)
      self:switchInput("Input"..hdmi)
    end
  end

  C.CurrentPreview.EventHandler = function() self:updatePreviewWindow() end

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
          NVX:updateDeviceType()
          NVX:buildDecoder()
          NVX:updatePreviewWindow()
        end
      })
    end
  })

  for name, boolean in pairs(NVX.reInits) do C[name].EventHandler = function() N:Init() end end

end

N:Init()


return NVX

-- Controls.MyButton.Style = json.encode({
--   IconString = string.char(0xef,0x88,0x94), -- change icon (use icons.lua)
--   Legend = "MyButton",                      -- change button label
--   Color = "#123456,                         -- set button color
--   IconColor = "#654321",                    -- set icon color
--   DrawChrome = true,                        -- apply rendering styles
--   CornerRadius = math.random(0,24),         -- set corner radius
--   Margin = math.random(0,10),               -- set margin
--   Padding = math.random(0,24),              -- set padding
--   IconAlignment = "Right",                  -- align icon left/right
--   HorizontalAlignment = "Right",            -- align text left/center/right
--   StrokeColor = "#000000",                  -- set border color
--   StrokeWidth = math.random(0,10),          -- set border size
-- })