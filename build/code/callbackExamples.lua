--promise like pattern
function N:chainCallbacks(...)
    local callbacks = {...}
    return function(t,c,d,e,h)
        for _, callback in ipairs(callbacks) do
            callback(t,c,d,e,h)
        end
    end
end

-- Then you could use it like:
newInput:login({
    eh = self:chainCallbacks(
        function() newInput:getConfigurationData() end,
        function() newInput:updateDeviceType() end
    )
})

--single method 
function N:initializeDevice()
    self:login({
        eh = function()
            self:getConfigurationData({
                eh = function()
                    self:updateDeviceType()
                end
            })
        end
    })
end

--state machine
function N:initializeDevice()
    local states = {
        login = function() self:login({eh = states.configure}) end,
        configure = function() self:getConfigurationData({eh = states.updateType}) end,
        updateType = function() self:updateDeviceType() end
    }
    states.login()
end