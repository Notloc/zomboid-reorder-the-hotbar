require "ISUI/ISHotbar"

-- I hate completely replacing functions, but I had to fix a section in the middle. See line 83.
ISHotbar.refresh = function(self)
	self.needsRefresh = false

	-- the clothingUpdate is called quite often, we check if we changed any clothing to be sure we need to refresh
	-- as it can be called also when adding blood/holes..
	local refresh = false;

	if not self.wornItems then
		self.wornItems = {};
		refresh = true;
	elseif self:compareWornItems() then
		refresh = true;
	end
	
	if not refresh then
		return;
	end

	local previousSlot = self.availableSlot;
	local newSlots = {};
	local newIndex = 2;
	local slotIndex = #self.availableSlot + 1;

	-- always have a back attachment
	local slotDef = self:getSlotDef("Back");
	newSlots[1] = {slotType = slotDef.type, name = slotDef.name, def = slotDef};
	
	self.replacements = {};
	table.wipe(self.wornItems)
	
	-- check to add new availableSlot if we have new equipped clothing that gives some
	-- we first do this so we keep our order in hotkeys (equipping new emplacement will make them goes on last position)
	for i=0, self.chr:getWornItems():size()-1 do
		local item = self.chr:getWornItems():getItemByIndex(i);
		table.insert(self.wornItems, item)
		-- Skip bags in hands
		if item and self.chr:isHandItem(item) then
			item = nil
		end
		-- item gives some attachments
		if item and item:getAttachmentsProvided() then
			for j=0, item:getAttachmentsProvided():size()-1 do
				local slotDef = self:getSlotDef(item:getAttachmentsProvided():get(j));
				if slotDef then
					newSlots[newIndex] = {slotType = slotDef.type, name = slotDef.name, def = slotDef};
					newIndex = newIndex + 1;
					if not self:haveThisSlot(slotDef.type) then
						self.availableSlot[slotIndex] = {slotType = slotDef.type, name = slotDef.name, def = slotDef, texture = item:getTexture()};
						slotIndex = slotIndex + 1;
						self:savePosition();
					else
						-- This sets the slot texture after loadPosition().
						for i2,slot in pairs(self.availableSlot) do
							if slot.slotType == slotDef.type then
								slot.texture = item:getTexture()
								break
							end
						end
					end
				end
			end
		end
		if item and item:getAttachmentReplacement() then -- item has a replacement
			local replacementDef = self:getSlotDefReplacement(item:getAttachmentReplacement());
			if replacementDef then
				for type, model in pairs(replacementDef.replacement) do
					self.replacements[type] = model;
				end
			end
		end
	end

	-- check if we're missing slots
	if #self.availableSlot ~= #newSlots then
		local removed = 0;
		if #self.availableSlot > #newSlots then
			removed = #self.availableSlot - #newSlots;
		end

        -- Loop backwards so we don't mess up the indexes
        -- Fixing this loop is why I had to override the entire function -_-
        local slotCount = #self.availableSlot
        for i=#self.availableSlot, 1, -1 do
            local slot = self.availableSlot[i];
            if slot and not self:haveThisSlot(slot.slotType, newSlots) then
				-- remove the attached item from the slot
				if self.attachedItems[i] then
					self:removeItem(self.attachedItems[i], false);
					self.attachedItems[i] = nil;
				end

				-- check if we had items in slots with bigger indexes and shift ALL of them
                -- The original code failed to handle removing slots in the middle of the list
                for j=1, slotCount-i do
                    local correctedIndex = i + j - 1;
                    if self.attachedItems[i + j] then
                        self.attachedItems[correctedIndex] = self.attachedItems[i + j];
                        self.attachedItems[correctedIndex]:setAttachedSlot(correctedIndex);
                        self.attachedItems[i + j] = nil;
                    end
                end
				self.availableSlot[i] = nil;
			end
        end
		self:savePosition();
	end
	
	newSlots = {};
	-- now we redo our correct order
	local currentIndex = 1;
	for i,v in pairs(self.availableSlot) do
		newSlots[currentIndex] = v;
		currentIndex = currentIndex + 1;
	end
	
	self.availableSlot = newSlots;
	
	-- we re attach out items, if we added a bag for example, we need to redo the correct attachment
	for i, item in pairs(self.attachedItems) do
        local slotI = item:getAttachedSlot();
		local slot = self.availableSlot[slotI];
		local slotDef = slot.def;
		local slotIndex = item:getAttachedSlot();
		self:removeItem(item, false);
		-- we get back what model it should be on, as it can change if we remove a replacement (have a bag + something on your back, remove bag, we need to get the original attached definition)
		if self.chr:getInventory():contains(item) and not item:isBroken() then
			self:attachItem(item, slotDef.attachments[item:getAttachmentType()], slotIndex, self:getSlotDef(slot.slotType), false);
		end
	end
	
	local width = #self.availableSlot * self.slotWidth;
	width = width + (#self.availableSlot - 1) * 2;
	self:setWidth(width + 10);

	self:reloadIcons();
end


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


local getIndexKey = function(slot)
    return slot.slotType..SORT_KEY_PREFIX
end

ReorderTheHotbar_Mod.getPreferredIndexes = function(player, slots)
    local playerModData = player:getModData()
    local preferredIndexes = {}
    for i=1, #slots do
        local slot = slots[i]
        local index = playerModData[getIndexKey(slot)] or DEFAULT_INDEXES[slot.slotType] or i
        preferredIndexes[slot] = index
    end
    return preferredIndexes
end

ISHotbar.pre_reorder_refresh = ISHotbar.refresh
ISHotbar.refresh = function(self)
    self:pre_reorder_refresh()
    self:reorderTheHotbar()
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

local indexToHotkey = function(index)
    if index == 1 then return getCore():getKey("Hotbar 1") end
    if index == 2 then return getCore():getKey("Hotbar 2") end
    if index == 3 then return getCore():getKey("Hotbar 3") end
    if index == 4 then return getCore():getKey("Hotbar 4") end
    if index == 5 then return getCore():getKey("Hotbar 5") end
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

            playerModData[getIndexKey(draggedSlot)] = index
            playerModData[getIndexKey(droppedSlot)] = self.draggingSlotIndex
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

-- Another full override, messy mod is messy :(
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
-- The nature of the rendering code means a full override is required, so we'll ensure we load last to avoid losing our changes.
local function OnLoad()
	ReorderTheHotbar_Mod.original_hotbar_render = ISHotbar.render
    ISHotbar.render = ISHotbar.reorder_render
end

Events.OnLoad.Add(OnLoad)