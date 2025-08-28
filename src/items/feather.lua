local feather = {}
feather.__index = feather

function feather.new()
    local self = setmetatable({}, feather)
    self.name = "Feather"
    self.description = "A light and fluffy feather."
    self.image = nil  -- We can add an image later
    self.stackable = true
    return self
end

return feather
