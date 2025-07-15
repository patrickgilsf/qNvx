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
      Legend = "<<Auth Error!>>"
    },
    [1] = {
      Color = "Green",
      Legend = "Authorized"
    },
    [2] = {
      Color = "Yellow",
      Legend = "Initializing..."
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
  return o
end

--clear out vales
function N:clearDecoderValues()
  C.PreviewImage.Style = rj.encode({
    DrawChrome = false,
    IconData = false,
    Legend = ''
  })
  for idx = 1,4 do
    self:updateAccordingToValue(C["CopyStream"][idx], "StateTriggers", 0)
    C["StreamName"][idx].String = ""
    if C["SysInfo"][idx] then C["SysInfo"][idx].String = "" end
    self:updateAccordingToValue(C["RouteButton_1"][idx], "StateTriggers", 0)
    self:updateAccordingToValue(C["RouteButton_2"][idx], "StateTriggers", 0)
    self:updateAccordingToValue(C["AssignToPreview"][idx], "StateTriggers", 0)
    C.CurrentStreamName.Legend = ""
    for name, control in pairs(Controls) do 
      if name:match("Current") then self:updateAccordingToValue(control, "StateTriggers", 0) end 
    end
  end
end

function N:authFb(s)
  self:updateAccordingToValue(C.AuthStatus, "AuthFeedback", s and 1 or 0)
  C.Status.Value = s and 0 or 2
  --clears out all values if not authorized
  if not s then self:clearDecoderValues() end
end 

function N:authFlow(inputData, fn)
  local doesNotReturnHtml = not inputData:match('<!DOCTYPE html>')
  self.returnAuthorized = doesNotReturnHtml and inputData --means we are getting data, and its not an html page
  self:authFb(NVX.Authorized)
  if not self.returnAuthorized then 
    self:login({
      eh = function()
        if fn then fn() end
      end
    })
  else 
    return self.returnAuthorized 
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

--login
function N:login(o)
  o = o or {}
  local credentialsFilledOut = self.ip ~= "" and self.un ~= "" and self.pw ~= ""
  if not credentialsFilledOut then print('Fill in credentials to initialize') return false end
  --login the first time
  HttpClient.Upload({
    Url = self.Urls.login,
    Method = 'POST',
    Headers = self.Header,
    Data = 'login='..self.un..'&&passwd='..self.pw,
    EventHandler = function (t,c,d,e,h)
      self.Authorized = h["Set-Cookie"] and c == 200
      self:authFb(self.Authorized)
      if self.Authorized then
        local str = ""
        for _, s in pairs(h["Set-Cookie"]) do str = str..s end
        self.Header.Cookie = str
      else
        if self.ip then print('Authentication Error with '..self.ip..'!') end
        print(h["Set-Cookie"], c)
      end
      if o.eh then return o.eh(t,c,d,e,h) end
    end
  })
end

--get configuration data
function N:getConfigurationData(o)
  o = o or {}
  local url = o.subPath and self.Urls.base.."/"..o.subPath or self.Urls.base
  if o.verbose then print('making request from '..url) end
  HttpClient.Download {
    Url = url,
    Headers = self.Header,
    Timeout = o.timeout or 10,
    EventHandler = function(t,c,d,e,h)
      self:authFlow(d)
      if not self.Authorized then 
        if self.ip then print(self.ip.." is not logged in") end
      else
        if o.verbose then print('logged into '..self.Urls.base) end
      end
      if o.verbose then print(d) end
      if c ~= 200 then
        if self.ip then print("Error getting data from "..url.." with code: "..c..":") end
        print(e) 
      else
        local encodedData = rj.decode(d)
        if not encodedData then print(self.Urls.base.." did not receive data") return false end
        if o.subPath then
          self.config.Device[o.subPath] = encodedData["Device"][o.subPath]
        else
          self.config = encodedData
          self:updateButtonFeedback()
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
        self:authFlow(d)
        if not o.externalUrl then
          local encodedData = rj.decode(d)
          if not encodedData then print(url.." did not receive data") return false end
        end
        if o.eh then return o.eh(t,c,d,e,h) end  
      end
    end
  }
end

--all things feedback
function N:pollSystemInfo()
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
function N:pollActiveSource(idx)
  if not self.config.Device then print('cannot poll active source without config file loaded') return false end
  self.activeVideoInput = (function() if self.config.Device.DeviceSpecific.ActiveVideoSource then return self.config.Device.DeviceSpecific.ActiveVideoSource end end)()
  self.outputIsDisabled = self.config.Device.AudioVideoInputOutput.Outputs[1].Ports[1].Hdmi.IsOutputDisabled
  if self.deviceMode == "Receiver" then
    self.routesControls = {
      ["CurrentStreamName"] = "Stream",
      ["CurrentRouteButton_1"] = "Input1",
      ["CurrentRouteButton_2"] = "Input2"
    }
  elseif self.deviceMode == "Transmitter" then
    if not idx then print('index needed to update polling for '..self.SessionName) return false end
    self.routesControls = {
      ["RouteButton_1"] = "Input1",
      ["RouteButton_2"] = "Input2"
    }
  end
  for controlName, source in pairs(self.routesControls) do
    local control
    if idx then control = C[controlName][idx] else control = C[controlName] end
    if self.deviceMode == "Receiver" and self.outputIsDisabled then 
      control.Value = 0
    else
      control.Value = source == self.activeVideoInput and 1 or 0
    end
    self:updateAccordingToValue(control, "StateTriggers", control.Value)
  end
end
function N:pollActiveStream()
  if self.deviceMode ~= "Receiver" then return end
  local routingTable = self.config.Device.AvRouting.Routes
  if #routingTable > 1 then print('multiple routes found, return first one') end
  local streamName = function()
    for sessionName, data in pairs(self.externalStreams) do
      if routingTable[1].VideoSource == data.id then 
        return "Stream: "..sessionName
      end
    end
    return "Stream: ".."<<NONE>>"
  end
  if self.externalStreams then C.CurrentStreamName.Legend = streamName() end 
end
function N:pollPreviewButtons(pre)
  if not self.currentPreview then return end
  self:updateAccordingToValue(C.CurrentPreview, "StateTriggers", self.currentPreview == "Main" and 1 or 0)
  for idx, ctl in pairs(C.AssignToPreview) do self:updateAccordingToValue(ctl, "StateTriggers", self.currentPreview == idx and 1 or 0) end
end
--attached to every get request
function N:updateButtonFeedback(o)
  o = o or {}
  self.deviceMode = self.config.Device.DeviceSpecific.DeviceMode
  self.activeVideoInput = self.config.Device.DeviceSpecific.ActiveVideoSource
  self:pollActiveSource(self.lastInput or false)
  self:pollActiveStream()
  NVX:pollPreviewButtons()
  if NVX.currentPreview == "Main" then NVX:assignPreviewToWindow() else self:assignPreviewToWindow(self.currentPreview) end
end

--route video from streams, according to uuid
function N:routeFromStream(uuid)
  local data = [=[{"Device": {"AvRouting": {"Routes": [{"VideoSource": "]=]..uuid..[=["}]}}}]=]
  self:postData("/AvRouting/Routes", data, {
    eh = function() NVX:getConfigurationData() end
  })
end

--switches a local input
function N:switchInput(input, id)
  if input ~= self.activeVideoInput then 
    local data = '{"Device": {"DeviceSpecific": {"VideoSource": "'..input..'"}}}'
    self:postData("/DeviceSpecific/VideoSource", data, {
      eh = function(t,c,d,e,h)
        self:getConfigurationData({
          eh = function()
            if id then NVX:routeFromStream(id) end
          end
        }) 
      end
    })
  else
    self:getConfigurationData({
      eh = function() if id then NVX:routeFromStream(id) end
    end
    })
  end
end

--disables the main output https://github.com/patrickgilsf/qNvx/issues/2
function N:disableMainOutput(disabled)
  local data = [=[{"Device":{"AudioVideoInputOutput":{"Outputs":[{"Ports":[{"Hdmi":{"IsOutputDisabled":]=]..tostring(disabled)..[=[}}]}]}}}]=]
  NVX:postData("/AudioVideoInputOutput/Outputs", data, {
    eh = function() self:getConfigurationData() end
  })
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
    end
  })
end
--update preview window
function N:updatePreviewWindow(o)
  NVX.currentPreview = o and o.idx or "Main"
  o = o or {}
  if not self.config then print('config file needs to be loaded to upload preview window') return false end
  self:getConfigurationData({
    eh = function()
      self:assignPreviewToWindow(o)
      if o.eh then o.eh() end
    end
  })
end

--save routes to system memory, location depends on whether live or emulating
function N:saveRouteToMemory(idx)
  local sIdx = tostring(idx)
  local sessionName = C.StreamName[idx].String
  local configData = self.externalStreams[sessionName]
  if not configData then
    print("You can't save a route with selecting from the dropdown box first ")
    return false
  end
  self.savedRoutes[idx] = {
    SessionName = configData.SessionName,
    id = configData.id,
    MulticastAddress = configData.MulticastAddress,
    ip = configData.ip
  }
  local routesFile = io.open(self.filePath, "w")
  if routesFile then
    routesFile:write(rj.encode(self.savedRoutes))
    routesFile:close()
    self:updateAccordingToValue(C.CopyStream[idx], "StateTriggers", 1)
  else
    print('cound not open file')
  end
end

--retrieves routes from saved memory
function N:retrieveSavedRoutesFromMemory(o)
  o = o or {}
  self.filePath = System.IsEmulating and "design/savedRoutes.json" or "media/savedRoutes.json"
  local routesFileCheck, routesFile
  if pcall(function()  assert(io.open(self.filePath, "r")) end) then 
    print('Found saved data file: '..self.filePath)
    routesFileCheck = assert(io.open(self.filePath, "r"))
    routesFile = routesFileCheck:read("*all")
    self.savedRoutes = rj.decode(routesFile)
  else
    print('Did not find file '..self.filePath..'...creating one')
    routesFileCheck = io.open(self.filePath, "w")
    self.savedRoutes = {}
  end
  routesFileCheck.close()
  if o.eh then return o.eh() else return routesFile end
end

--sets up transmitter 
function N:initializeTransmitter(idx)
  if self.inputTable then table.insert(self.inputTable, idx) else self.inputTable = {idx} end
  self.lastInput = idx
  if not idx then print('index needed to initialize transmitter') return false end
  self:login({
    eh = function() 
      if not self.Authorized then
        print(self.ip..' was discovered, but did not log in successfully!')
      else
        self:getConfigurationData()
      end
    end
  }) 
end

-- sets up main receiver
function N:initializeMainRecevier()

  --add system info to plugin pane
  self:pollSystemInfo()

  --Authorization button will re-initialize script
  C.AuthStatus.EventHandler = function()
      N:Init()
  end

  --gather discovered streams
  if not self.config.Device.DiscoveredStreams then print("gather discoveredStreams data first before populating streams list") return end
  local streamsPulled = self.config.Device.DiscoveredStreams.Streams
  if streamsPulled == {} then print('no streams to acquire') return end

  --new N instance for any stream discovered
  self.externalStreams, self.dropdownList = {}, {}
  for uuid, data in pairs(streamsPulled) do
    data.id = uuid
    data.ip = data.Address:match("^https?://([^/]+)/onvif/services$".."")    
    data.Address = "https://"..data.ip --removes other address field
    data.un = self.un
    data.pw = self.pw
    local newInput = N:new(data)
    self.externalStreams[data.SessionName] = newInput
    table.insert(self.dropdownList, data.SessionName)
  end

  --helper function looks up streams in table
  local function isDiscoveredStream(sessionName)
    for __,session in pairs(self.dropdownList) do 
        if session == sessionName then return true end
    end
    return false
  end
  
  --compare discovered streams against saved streams
  if not self.savedRoutes then self.savedRoutes = {} end
  for idx, stream in pairs(self.savedRoutes) do
    self:updateAccordingToValue(C.CopyStream[idx], "StateTriggers", 0)
    if isDiscoveredStream(stream.SessionName) then
      C.StreamName[idx].String = stream.SessionName
      self:updateAccordingToValue(C.CopyStream[idx], "StateTriggers", 1)
      local newInput= self.externalStreams[stream.SessionName]
      newInput:initializeTransmitter(idx)      
    end
  end

  --iterate through 4 controls with saved data
  for idx, ct in pairs(C.StreamName) do
    ct.Choices = self.dropdownList
    ct.EventHandler = function()
      self:updateAccordingToValue(C.CopyStream[idx], "StateTriggers", 0)
      self.externalStreams[ct.String]:initializeTransmitter(idx) 
    end        
    C.CopyStream[idx].EventHandler = function() self:saveRouteToMemory(idx) end
    C.AssignToPreview[idx].EventHandler = function(c)
      self.externalStreams[ct.String]:updatePreviewWindow({idx = idx})
    end
    for hdmiIdx = 1, 2 do 
      local btn = C["RouteButton_"..hdmiIdx][idx]
      btn.Legend = "HDMI "..hdmiIdx
      btn.EventHandler = function(c)
        if ct.String == "" then print('you must choose a stream before you can route') return false end
        local tx = self.externalStreams[ct.String]
        tx:switchInput("Input"..hdmiIdx, tx.id)
      end            
    end
  end
  
  --setup "Current Stream" section 
  for controlName, source in pairs(self.routesControls) do
    local control = C[controlName]
    if source == "Stream" then 
      self:pollActiveStream()
    else
      control.Legend = "HDMI "..source:match("%d")
    end
    control.EventHandler = function()
      if control.Value == 0 then
        if self.outputIsDisabled then self:disableMainOutput(false) end 
        self:switchInput(source)
      elseif control.Value == 1 then
        self:disableMainOutput(true)
      end
    end
  end

  self:updatePreviewWindow()
  C.CurrentPreview.EventHandler = function() self:updatePreviewWindow() end

end

function N:openingComments()
  local systemIp = Network.Interfaces()[1].Address
  local systemStr = System.IsEmulating and 'System is Emulating with IP address ' or 'System is live with IP address '
  print(systemStr..systemIp)
  print("\nYou are now running a Q-Sys/Crestron NVX Demo script!\n\n- This is a Proof of Concept and should not be used in production!\n- If you discover any bugs, please report them as an issue in https://github.com/patrickgilsf/qNvx/issues.\n\nEnjoy!")
end

function N:Init()

  NVX = N:new({
    ip = C.IP.String,
    un = C.Username.String,
    pw = C.Password.String
  })

  --initialization feedback
  NVX:updateAccordingToValue(C.AuthStatus, "AuthFeedback", 2)
  
  --clear values before starting
  NVX:clearDecoderValues()

  NVX:login({

    eh = function()
      if not NVX.Authorized then print('Receiver is not logged in!') return end
      --clear values before starting
      NVX:getConfigurationData({
        eh = function()
          NVX:retrieveSavedRoutesFromMemory({
            eh = function() NVX:initializeMainRecevier() end
          })          
        end
      })
    end
  })

  for name, boolean in pairs(NVX.reInits) do C[name].EventHandler = function() N:Init() end end
  

end

N:openingComments()
N:Init()

return NVX