-- Listener List, binds all listened-to events to one signal
-- Dynamese(Enduo)
-- 02.06.22



local DeepObject = require(script.Parent.DeepObject)
local ListenerList = {}
ListenerList.__index = ListenerList
setmetatable(ListenerList, DeepObject)


function ListenerList.new(...)
    local self = setmetatable(DeepObject.new({
        _events = {};
        _callbacks = {};
    }), ListenerList)

    for _, signal in ipairs({...}) do
        self:Add(signal)
    end

	return self
end


function ListenerList:ExecuteCallbacks(...)
    for _, callback in ipairs(self._callbacks) do
        callback(...)
    end
    return self
end


function ListenerList:Add(signal)
    table.insert(self._events, signal:Connect(function(...) self:ExecuteCallbacks(...) end))
    return self
end


function ListenerList:Connect(callback)
    table.insert(self._callbacks, callback)
    return self
end


function ListenerList:Destroy()
    for _, event in ipairs(self._events) do
        event:Disconnect()
    end
    getmetatable(ListenerList).Destroy(self)
end


ListenerList.Disconnect = ListenerList.Destroy


return ListenerList
