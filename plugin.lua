-- Control Crestron NVX Encoders and Decoders with Q-Sys
-- @Author: Patrick Gilligan <https://github.com/patrickgilsf>
-- Spring 2024

PluginInfo = {
  Name = "qNVX",
  Version = "1.0",
  BuildVersion = "1.0.0.1",
  Id = "<guid>",
  Author = "Patrick Gilligan",
  Description = "Control Crestron NVX Encoders and Decoders with Q-Sys"
}

function GetColor()
  return { 153, 153, 153 }
end

function GetPrettyName(props)
  return string.format("qNVX v%s", PluginInfo.Version)
end

function GetPages()
  return {
    {name = "Control"},
    {name = "Setup"}
  }
end

function GetProperties()
  return {
    {Name = "NVX", Type = "enum", Choices = {"Encoder", "Decoder"}, Value = "Encoder"}
  }
end