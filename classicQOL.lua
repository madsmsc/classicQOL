-- Suppress undefined global warnings for WoW API
local GameTooltip, CreateFrame, UIParent, SlashCmdList, SendChatMessage =
    GameTooltip, CreateFrame, UIParent, SlashCmdList, SendChatMessage
local C_Container, GetItemInfo, ClearCursor, DeleteCursorItem =
    C_Container, GetItemInfo, ClearCursor, DeleteCursorItem
local UnitName, UnitLevel, UnitIsDead, UnitIsGhost, RequestTimePlayed =
    UnitName, UnitLevel, UnitIsDead, UnitIsGhost, RequestTimePlayed

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

local function findCheaperItem(item, bag, slot, names)
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
            findCheaperItem(item, bag, slot, names)
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
    local pos = "CENTER" -- "BOTTOMRIGHT"
    local template = "BasicFrameTemplateWithInset"
    local uiConfig = CreateFrame("Frame", "MyAddon", UIParent, template)
    uiConfig:SetSize(150, 105)
    uiConfig:SetPoint(pos, UIParent, pos)
    return uiConfig
end

local function makeTitle(uiConfig)
    local pos = "CENTER" -- "BOTTOM"
    uiConfig.title = uiConfig:CreateFontString(nil, "OVERLAY")
    uiConfig.title:SetFontObject("GameFontHighlight")
    uiConfig.title:SetPoint(pos, uiConfig.TitleBg, pos, 0, 0)
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

    -- set outline for quest items (classID 12)
    if item.itype == "Quest" then
        uiConfig.button:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- default border texture
            edgeSize = 12
        })
        uiConfig.button:SetBackdropBorderColor(1, 1, 0, 1) -- yellow (RGBA)
    end

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

-- return table
local function strSplit(str)
    local result = {}
    for word in string.gmatch(str, "[^%s]+") do
        table.insert(result, word)
    end
    return result
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
    local cols = 4
    local rows = 2
    if spaces == 2 then
        local args = strSplit(command)
        cols = tonumber(args[1]) or cols -- Ensure numeric conversion
        rows = tonumber(args[2]) or rows -- Ensure numeric conversion
    end
    makeUI(item, cols, rows)
end

-- report the state of the characters
local function hcReport()
    if ClassicQolState == nil or ClassicQolState.chars == nil then
        print("did not update state yet...")
        return
    end
    local chars = ClassicQolState.chars
    local aliveLevels = 0
    local aliveHours = 0
    local deadLevels = 0
    local deadHours = 0
    local alive = 0
    local dead = 0
    for _, c in pairs(chars) do
        if c.isAlive then
            aliveLevels = aliveLevels + c.levels
            aliveHours = aliveHours + c.hours
            alive = alive + 1
        else
            deadLevels = deadLevels + c.levels
            deadHours = deadHours + c.hours
            dead = dead + 1
        end
    end
    print(alive .. " chars alive with " .. aliveLevels
        .. " levels and " .. aliveHours .. " hours")
    print(dead .. " chars dead with " .. deadLevels
        .. " levels and " .. deadHours .. " hours")
end

-- save the current character state
local function updateStateOther()
    ClassicQolState = ClassicQolState or {}
    ClassicQolState.chars = ClassicQolState.chars or {} -- init chars table
    local chars = ClassicQolState.chars
    local playerName = UnitName("player")
    if chars[playerName] == nil then
        chars[playerName] = {}
    end
    RequestTimePlayed()
    chars[playerName].levels = UnitLevel("player")
    local isDead = UnitIsDead("player")
    local isGhost = UnitIsGhost("player")
    chars[playerName].isAlive = not isDead and not isGhost
    print("updated " .. playerName .. ": level="
        .. chars[playerName].levels .. " isAlive="
        .. tostring(chars[playerName].isAlive))
end

local function updateStateHours(event, totalTime, levelTime)
    local playerName = UnitName("player")
    local chars = ClassicQolState.chars
    ClassicQolState.chars[playerName].hours = tonumber(string.format("%.2f", totalTime / 3600)) -- Convert seconds to hours
    print("updated " .. playerName .. ": hours="
        .. chars[playerName].hours)
end

-- Create a frame to listen for events
local eventFrame = CreateFrame("Frame")
local loadEvent = "PLAYER_ENTERING_WORLD"
local timeEvent = "TIME_PLAYED_MSG"
eventFrame:RegisterEvent(timeEvent)
eventFrame:RegisterEvent(loadEvent)
-- Set a script to handle the event
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == timeEvent then
        updateStateHours(event, ...)
    elseif event == loadEvent then
        updateStateOther()
    end
end)

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
    elseif command == "r" then              -- report the state of the characters
        hcReport()
    else                                    -- SAY unknown command
        SendChatMessage("unknown command " .. command, "SAY", nil, nil)
    end
end

-- slash command aliases
SLASH_CQ1 = "/classicqol"
SLASH_CQ2 = "/cq"
-- register the slash command
SlashCmdList["CQ"] = startCommand
--[[ When a player types /classicqol or /cqol in the chat,
WoW looks up the CQOL entry in SlashCmdList
and calls the associated function (startCommand)
with any additional arguments passed as a string ]] --

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
