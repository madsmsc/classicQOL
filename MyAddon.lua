SLASH_MADS1 = "/madsaddon"
SLASH_MADS2 = "/mads"

--[[ 
    NOTES
wiki: https://wowpedia.fandom.com/wiki
enable lua errors: 
  /console scriptErrors 1         or 
disable: 
  /console scriptErrors 0
UnitName("player")
message("face")
itype == "Miscellaneous" or itype == "Junk"
layers:
background, border, artwork, overlay, hightlight

    TODO
updateItem: dot notation instead of array index notation?
introduce filter on itemType?
IMPORTANT!! mouseover button shows normal tooltip!
]]--

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

    item["bag"] = bag
    item["slot"] = slot
    item["name"] = itemName
    item["itype"] = itemType
    item["price"] = sellPrice * containerInfo.stackCount
    item["tex"] = itemTexture
end

local function cheapest(names)
    local item = {
        ["price"] = 999999,
        ["bag"] = "bag",
        ["slot"] = "slot",
        ["name"] = "name",
        ["itype"] = "itype",
        ["tex"] = "tex"
    }
    for bag = 0, 4 do
        local maxSlots = C_Container.GetContainerNumSlots(bag)
        -- SendChatMessage("checking bag " .. bag .. " slots " .. maxSlots, "SAY", nil, nil)
        for slot = 1, maxSlots do
            updateItem(item, bag, slot, names)
        end
    end
    return item;
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

local POSITION = "CENTER" -- "BOTTOMRIGHT"
local ROWS = 2
local COLUMNS = 4

local function makeFrame()
    local template = "BasicFrameTemplateWithInset"
    local uiConfig = CreateFrame("Frame", "MyAddon", UIParent, template)
    uiConfig:SetSize(150, 105)
    uiConfig:SetPoint(POSITION, UIParent, POSITION)
    return uiConfig;
end

local function makeTitle(uiConfig)
    uiConfig.title = uiConfig:CreateFontString(nil, "OVERLAY")
    uiConfig.title:SetFontObject("GameFontHighlight")
    uiConfig.title:SetPoint("CENTER", uiConfig.TitleBg, "CENTER", 0, 0)
    uiConfig.title:SetText("Cheapest items:")
end

local function makeButton(uiConfig, item, column, yoff)
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
    uiConfig.button:SetScript("OnClick", 
        function (self, button, down) 
            deleteItem(item)
        end)
end

local function makeUI(firstItem)
    local uiConfig = makeFrame()
    makeTitle(uiConfig)
    local item = firstItem
    local names = {}
    for row = 0, ROWS-1, 1 do
        for column = 0, COLUMNS-1, 1 do
            item = cheapest(names)
            if item.name == nil or item.name == "name" then return end
            makeButton(uiConfig, item, column, -20 + 40 * row)
            table.insert(names, item.name)
        end
    end
end

local function startCommand(command)
    local item = cheapest()
    if item.itype == nil then
        noJunk()
    elseif string.len(command) == 0 then
        sayCheapest(item)
    elseif command == "ui" then
        makeUI(item)
    elseif command == "d" then
        deleteItem(item)
    else
        SendChatMessage("unknown command " .. command, "SAY", nil, nil)
    end
end

SlashCmdList["MADS"] = startCommand
