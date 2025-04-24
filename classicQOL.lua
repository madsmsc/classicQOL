-- Suppress undefined global warnings for WoW API
local GameTooltip, CreateFrame, UIParent, SlashCmdList, SendChatMessage =
    GameTooltip, CreateFrame, UIParent, SlashCmdList, SendChatMessage
local C_Container, GetItemInfo, ClearCursor, DeleteCursorItem =
    C_Container, GetItemInfo, ClearCursor, DeleteCursorItem

-- SAY contents of table - used for debugging
local function sayTable(table)
    if table == nil then
        return
    end
    local msg = ""
    for i = 1, #table do
        msg = msg .. table[i]
    end
    SendChatMessage(msg, "SAY", nil, nil)
end

local function contains(table, element)
    if table == nil then
        return false
    end
    for i = 1, #table do
        if table[i] == element then
            return true
        end
    end
    return false
end

local function updateItem(item, bag, slot, names)
    -- sayTable(names)
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
    if containerInfo == nil or containerInfo.hyperlink == nil then
        -- SendChatMessage("nil containerInfo or hyperlink", "SAY", nil, nil)
        return
    end

    local itemName, infoItemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
    itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
    expacID, setID, isCraftingReagent = GetItemInfo(containerInfo.hyperlink)
    if contains(names, itemName) then
        -- SendChatMessage("names already contain " .. itemName, "SAY", nil, nil)
        return
    end

    local exists = itemName ~= nil and sellPrice > 0
    if not exists then
        -- SendChatMessage(itemName .. " or " .. sellPrice .. "doesn't exist", "SAY", nil, nil)
        return
    end
    local cheaper = sellPrice * containerInfo.stackCount < item.price
    if not cheaper then
        return
    end

    item.bag = bag
    item.slot = slot
    item.name = itemName
    item.itype = itemType
    item.price = sellPrice * containerInfo.stackCount
    item.tex = itemTexture
end

local function cheapest(names)
    local item = {
        price = 999999,
        bag = "bag",
        slot = "slot",
        name = "name",
        itype = "itype",
        tex = "tex"
    }
    for bag = 0, 4 do
        local maxSlots = C_Container.GetContainerNumSlots(bag)
        -- SendChatMessage("checking bag " .. bag .. " slots " .. maxSlots, "SAY", nil, nil)
        for slot = 1, maxSlots do
            updateItem(item, bag, slot, names)
        end
    end
    return item
end

local function noJunk()
    local msg = "\nNo junk items..."
    SendChatMessage(msg, "SAY", nil, nil)
end

local function deleteItem(item)
    ClearCursor()
    C_Container.PickupContainerItem(item.bag, item.slot)
    DeleteCursorItem()
end

local function sayCheapest(item)
    local msg = "Cheapest [" .. item.name .. "] ["
        .. item.price .. "c] [" .. item.itype .. "]"
    SendChatMessage(msg, "SAY", nil, nil)
end

local function makeFrame()
    local POSITION = "CENTER" -- "BOTTOMRIGHT"
    local template = "BasicFrameTemplateWithInset"
    local uiConfig = CreateFrame("Frame", "MyAddon", UIParent, template)
    uiConfig:SetSize(150, 105)
    uiConfig:SetPoint(POSITION, UIParent, POSITION)
    return uiConfig
end

local function makeTitle(uiConfig)
    uiConfig.title = uiConfig:CreateFontString(nil, "OVERLAY")
    uiConfig.title:SetFontObject("GameFontHighlight")
    uiConfig.title:SetPoint("CENTER", uiConfig.TitleBg, "CENTER", 0, 0)
    uiConfig.title:SetText("Cheapest items:")
end

local function makeButton(uiConfig, item, column, yoff)
    -- create button
    local template = "GameMenuButtonTemplate"
    uiConfig.button = CreateFrame("Button", nil, uiConfig, template)
    local size = 35
    local hPos = size / 2 + column * size + 5
    uiConfig.button:SetPoint("CENTER", uiConfig, "LEFT", hPos, -8 + yoff)
    uiConfig.button:SetSize(size, size)
    uiConfig.button:SetText(item.price)
    uiConfig.button:SetNormalFontObject("GameFontNormalLarge")
    uiConfig.button:SetHighlightFontObject("GameFontHighlightLarge")
    uiConfig.button:SetNormalTexture(item.tex)

    -- set scripts
    uiConfig.button:SetScript("OnClick", function(self, button, down) -- maybe button/down can be omitted
            deleteItem(item)
    end)
    uiConfig.button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(item.bag, item.slot)
        GameTooltip:Show()
    end)
    uiConfig.button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- return array of elements separated by spaces
-- maybe try with " " instead of regexp
local function strSplit(str)
    return string.gmatch(str, "[^%s]+")
end

-- return number of occurances
local function strCount(base, pattern)
    return select(2, string.gsub(base, pattern, ""))
end

-- render the item deletion UI
local function makeUI(firstItem, cols, rows)
    local uiConfig = makeFrame()
    makeTitle(uiConfig)
    local item = firstItem
    local names = {}
    for row = 0, rows - 1, 1 do
        for column = 0, cols - 1, 1 do
            item = cheapest(names)
            if item.name == nil or item.name == "name" then return end
            makeButton(uiConfig, item, column, -20 + 40 * row)
            table.insert(names, item.name)
        end
    end
end

-- call makeUI based on the arguments
local function makeUIargs(item, command)
    local spaces = strCount(command, " ")
    local rows = 2
    local cols = 4
    if spaces == 2 then
        local args = strSplit(command)
        cols = args[1]
        rows = args[2]
    end
    makeUI(item, rows, cols)
end

-- parse the slash command and args
local function startCommand(command)
    local item = cheapest()
    if item.itype == nil then               -- SAY there are no junk items
        noJunk()
    elseif string.len(command) == 0 then    -- SAY the cheapest item
        sayCheapest(item)
    elseif string.match(command, "ui") then -- render the UI
        makeUIargs(item, command)
    elseif command == "d" then              -- delete the cheapest item
        deleteItem(item)
    else                                    -- SAY unknown command
        SendChatMessage("unknown command " .. command, "SAY", nil, nil)
    end
end

-- slash command aliases
SLASH_CQOL1 = "/classicqol"
SLASH_CQOL2 = "/cqol"
-- register the slash command
SlashCmdList["CQOL"] = startCommand
--[[ When a player types /classicqol or /cqol in the chat, 
WoW looks up the CQOL entry in SlashCmdList 
and calls the associated function (startCommand) 
with any additional arguments passed as a string ]]--

--[[ NOTES
wiki: https://wowpedia.fandom.com/wiki
enable lua errors:
  /console scriptErrors 1
disable:
  /console scriptErrors 0
UnitName("player")
message("face")
itype == "Miscellaneous" or itype == "Junk"
layers:
background, border, artwork, overlay, hightlight ]] --
