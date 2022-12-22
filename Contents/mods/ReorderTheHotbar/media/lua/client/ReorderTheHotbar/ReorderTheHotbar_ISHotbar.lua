require "ISUI/ISHotbar"

ReorderTheHotbar_Mod = {}

local SORT_KEY_PREFIX = "RTH_index"
local LOCK_KEY = "RTH_locked"

local DEFAULT_INDEXES = {
    ["Back"] = 1,
    ["SmallBeltLeft"] = 2,
    ["SmallBeltRight"] = 3,
    ["HolsterLeft"] = 4,
    ["HolsterRight"] = 5,
}

local LOCK_TEX = getTexture("media/ui/ReorderTheHotbar/locked.png")
local UNLOCK_TEX = getTexture("media/ui/ReorderTheHotbar/unlocked.png")
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)


local getSlotKey = function(slot)
    return slot.slotType..SORT_KEY_PREFIX
end

ReorderTheHotbar_Mod.getPreferredIndexes = function(player, slots)
    local playerModData = player:getModData()
    local preferredIndexes = {}
    for i=1, #slots do
        local slot = slots[i]
        local index = playerModData[getSlotKey(slot)] or DEFAULT_INDEXES[slot.slotType] or i
        preferredIndexes[slot] = index
    end
    return preferredIndexes
end

ISHotbar.pre_reorder_refresh = ISHotbar.refresh
ISHotbar.refresh = function(self)
    if NATTBackpacks and not self.skippedOneForNATT then -- I hate doing this kinda thing, but its fairly harmless as far as compatibility workarounds go
        -- But in general, I'd rather my mods not know that other mods exist
        self:pre_reorder_refresh()
        self.needsRefresh = true
        self.skippedOneForNATT = true
    else
        self:sortSlotsThatAreAboutToBeRemovedToTheBack()
        self:pre_reorder_refresh()
        self:reorderTheHotbar()
    end
end

ISHotbar.sortSlotsThatAreAboutToBeRemovedToTheBack = function(self)
    local refresh = false;
	
    if not self.wornItems then
		self.wornItems = {};
		refresh = true;
	elseif self:compareWornItems() then
		refresh = true;
	end
	
    -- Only run if the real refresh will run
	if not refresh then
		return;
	end

    local availableSlotTypes = {}

	-- always have a back attachment
	local slotDef = self:getSlotDef("Back");
    availableSlotTypes[slotDef.type] = true

	for i=0, self.chr:getWornItems():size()-1 do
		local item = self.chr:getWornItems():getItemByIndex(i);

		-- Skip bags in hands
		if item and self.chr:isHandItem(item) then
			item = nil
		end
		-- item gives some attachments
		if item and item:getAttachmentsProvided() then
			for j=0, item:getAttachmentsProvided():size()-1 do
				local slotDef = self:getSlotDef(item:getAttachmentsProvided():get(j));
				if slotDef then
					availableSlotTypes[slotDef.type] = true
				end
			end
		end
	end

    local newSlots = {}
    local newItems = {}

    local newIndex = 1
    for index, slot in ipairs(self.availableSlot) do
        if availableSlotTypes[slot.slotType] then
            newSlots[newIndex] = slot
            newItems[newIndex] = self.attachedItems[index]
            if newItems[newIndex] then
                newItems[newIndex]:setAttachedSlot(newIndex)
            end

            newIndex = newIndex + 1
        end
    end

    for index, slot in ipairs(self.availableSlot) do
        if not availableSlotTypes[slot.slotType] then
            newSlots[newIndex] = slot
            newItems[newIndex] = self.attachedItems[index]
            if newItems[newIndex] then
                newItems[newIndex]:setAttachedSlot(newIndex)
            end
            newIndex = newIndex + 1
        end
    end

    self.availableSlot = newSlots
    self.attachedItems = newItems

    self.wornItems = nil -- Ensures the real call to refresh will run
end

ISHotbar.reorderTheHotbar = function(self)
    local preferredIndexes = ReorderTheHotbar_Mod.getPreferredIndexes(self.character, self.availableSlot)

    -- Map the items to the slots
    local items = self.attachedItems or {}
    for i=1, #self.availableSlot do
        self.availableSlot[i].item = items[i]
    end

    -- Reorder the slots
    table.sort(self.availableSlot, function(a, b)
        return preferredIndexes[a] < preferredIndexes[b]
    end)
    
    -- Update the items
    self.attachedItems = {}
    for i=1, #self.availableSlot do
        local slot = self.availableSlot[i]
        if slot.item then
            self.attachedItems[i] = slot.item
            slot.item:setAttachedSlot(i)
        end
    end

    -- Save the new order
    local modData = self.character:getModData()
    for i=1, #self.availableSlot do
        local slot = self.availableSlot[i]
        modData[getSlotKey(slot)] = i
    end
end

-- Full overriding this one because I need to remove its custom way of determining the slot index
-- It would open the right click menu on the wrong slot because it doesn't take into account each slot's padding
ISHotbar.onRightMouseUp = function(self, x, y)
	local clickedSlot = self:getSlotIndexAt(x, y)
    if clickedSlot ~= -1 then
        self:doMenu(clickedSlot);
    end
end


ISHotbar.onMouseDown = function(self, x, y)
    self.lastClickTime = getTimestampMs()
    local isLocked = self.character:getModData()[LOCK_KEY]
    local index = self:getSlotIndexAt(x, y)
    if index > -1 and not isLocked then
        self.draggingSlotIndex = index
        self.draggingSlotStartX = x
        self.draggingSlotStartY = y
    end
end

ISHotbar.onMouseMove = function(self, _, __)
    if self.draggingSlotIndex then
        local x = self:getMouseX()
        local y = self:getMouseY()
        local dx = x - self.draggingSlotStartX
        local dy = y - self.draggingSlotStartY
        if math.abs(dx) + math.abs(dy) > 16 then
            self.isDraggingASlot = true
        end
    end
end

-- To 20 for Noir's mod
local indexToHotkey = function(index)
    if index == 1 then return getCore():getKey("Hotbar 1") end
    if index == 2 then return getCore():getKey("Hotbar 2") end
    if index == 3 then return getCore():getKey("Hotbar 3") end
    if index == 4 then return getCore():getKey("Hotbar 4") end
    if index == 5 then return getCore():getKey("Hotbar 5") end
    if index == 6 then return getCore():getKey("Hotbar 6") end
    if index == 7 then return getCore():getKey("Hotbar 7") end
    if index == 8 then return getCore():getKey("Hotbar 8") end
    if index == 9 then return getCore():getKey("Hotbar 9") end
    if index == 10 then return getCore():getKey("Hotbar 10") end
    if index == 11 then return getCore():getKey("Hotbar 11") end
    if index == 12 then return getCore():getKey("Hotbar 12") end
    if index == 13 then return getCore():getKey("Hotbar 13") end
    if index == 14 then return getCore():getKey("Hotbar 14") end
    if index == 15 then return getCore():getKey("Hotbar 15") end
    if index == 16 then return getCore():getKey("Hotbar 16") end
    if index == 17 then return getCore():getKey("Hotbar 17") end
    if index == 18 then return getCore():getKey("Hotbar 18") end
    if index == 19 then return getCore():getKey("Hotbar 19") end
    if index == 20 then return getCore():getKey("Hotbar 20") end
    return -1
end

ISHotbar.pre_reorder_onMouseUp = ISHotbar.onMouseUp
ISHotbar.onMouseUp = function(self, x, y)
    local index = self:getSlotIndexAt(x, y)
    
    -- Only allow the original function to run if we can find an index
    if index ~= -1 then
        self:pre_reorder_onMouseUp(x, y)
    end
    
    if self.isDraggingASlot then
        if index ~= -1 and index ~= self.draggingSlotIndex then
            local playerModData = self.character:getModData()

            local draggedSlot = self.availableSlot[self.draggingSlotIndex]
            local droppedSlot = self.availableSlot[index]

            playerModData[getSlotKey(draggedSlot)] = index
            playerModData[getSlotKey(droppedSlot)] = self.draggingSlotIndex

            self.wornItems = nil
            self:refresh()
            self:savePosition()
        end
    elseif index > -1 and getTimestampMs() - (self.lastClickTime or 0) < 150 then   
        local key = indexToHotkey(index)
        self.onKeyStartPressed(key)
        self.onKeyPressed(key)
    else
        -- Check if we clicked the lock icon
        local slotCount = #self.availableSlot
        local lockIconX = self.margins + (self.slotWidth + self.slotPad) * slotCount
        if x > lockIconX and x < lockIconX + 18 and y > 0 and y < 18 then
            local playerModData = self.character:getModData()
            playerModData[LOCK_KEY] = not playerModData[LOCK_KEY]
            getSoundManager():playUISound("UIToggleTickBox")
        end
    end

    self.isDraggingASlot = false
    self.draggingSlotIndex = nil
    self.draggingSlotStartX = nil
    self.draggingSlotStartY = nil
end

ISHotbar.onMouseUpOutside = function(self, x, y)
    self:onMouseUp(x, y)
end

ISHotbar.reorder_render = function(self)
    ReorderTheHotbar_Mod.original_hotbar_render(self)
    
    -- Render a lock icon at the edge of the hotbar
    local slotCount = #self.availableSlot
    local x = self.margins + (self.slotWidth + self.slotPad) * slotCount

    self:drawRect(x, 0, 18, 18, 0.8, 0, 0, 0);
    self:drawRectBorderStatic(x, 0, 18, 18, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    
    local playerModData = self.character:getModData()
    local texture = playerModData[LOCK_KEY] and LOCK_TEX or UNLOCK_TEX
    self:drawTexture(texture, x+1, 1, 1, 1, 1, 1)

    if self.isDraggingASlot then
        -- Render the slot being dragged under the mouse
        local slot = self.availableSlot[self.draggingSlotIndex]
        local item = self.attachedItems[self.draggingSlotIndex]
        
        local x = self:getMouseX() - self.slotWidth / 2
        local y = self:getMouseY() - self.slotHeight / 2

        self:drawRectBorderStatic(x, y, self.slotWidth, self.slotHeight, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
        
        local slotName = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name;
        local textWid = getTextManager():MeasureStringX(UIFont.Small, slotName)
        self:drawText(slotName, x + (self.slotWidth - textWid) / 2, y -FONT_HGT_SMALL, self.textColor.r, self.textColor.g, self.textColor.b, self.textColor.a, self.font);

        if item then
			local tex = item:getTexture()
            self:drawTexture(tex, x + (tex:getWidth() / 2), y + (tex:getHeight() / 2), 1, 1, 1, 1)
        end
    end
end

ISHotbar.getSlotIndexAt = function(self, x, y)
	if x >= 0 and x < self.width and y >= 0 and y < self.height then
		local index = math.floor((x - self.margins) / (self.slotWidth + self.slotPad)) + 1
		index = math.max(index, 1)
		if index <= #self.availableSlot then
            return index
        end
	end
	return -1
end

ISHotbar.pre_reorder_setSizeAndPosition = ISHotbar.setSizeAndPosition
ISHotbar.setSizeAndPosition = function(self)
    self:pre_reorder_setSizeAndPosition()
    self:setWidth(self:getWidth() + 18)
end

ISHotbar.pre_reorder_loadPosition = ISHotbar.loadPosition
ISHotbar.loadPosition = function(self)
    self:reorderTheHotbar()
    self:pre_reorder_loadPosition()
end

-- Wait for the load event so we can avoid conflicts with mods that override the ISHotbar rendering.
-- The nature of the rendering code means a full override is likely, so we'll ensure we load last to avoid losing our changes.
local function OnLoad()
	ReorderTheHotbar_Mod.original_hotbar_render = ISHotbar.render
    ISHotbar.render = ISHotbar.reorder_render
end

Events.OnLoad.Add(OnLoad)