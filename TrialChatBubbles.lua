local BUBBLE_MAX_WIDTH = 220
local BUBBLE_OFFSET_Y = 52
local BUBBLE_TAIL_OFFSET_X = -16
local BUBBLE_TAIL_OFFSET_Y = 16
local BUBBLE_MIN_SECONDS = 4
local BUBBLE_MAX_SECONDS = 12
local BUBBLE_SECONDS_PER_BYTE = 0.05
local BUBBLE_FADE_SECONDS = 0.5
local MAX_NAMEPLATES = 40

TrialChatBubbles = {}

local bubblesByPlate = {}
local bubblesByUnit = {}

local function isBubblesEnabled()
    return not (TrialChatDB and TrialChatDB.chatBubbles == false)
end

-- Bubbles float in the game world, so only plain text is shown: links keep
-- their visible text, everything else that could render markup is removed.
local function toPlainText(text)
    text = string.gsub(text, "||", "\1")
    text = string.gsub(text, "|H.-|h(.-)|h", "%1")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|cn[^:|]*:", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|[TAK].-|[tak]", "")
    text = string.gsub(text, "|", "||")
    return (string.gsub(text, "\1", "||"))
end

local function findNamePlateUnit(sender)
    local senderKey = TrialChatCommon.NormalizeCharacterName(sender)
    for index = 1, MAX_NAMEPLATES do
        local unit = "nameplate" .. index
        if UnitExists(unit) and UnitIsPlayer(unit)
            and C_NamePlate.GetNamePlateForUnit(unit) then
            local name, realm = UnitFullName(unit)
            local isSecret = issecretvalue
                and (issecretvalue(name) or issecretvalue(realm))
            if not isSecret and name then
                if realm and realm ~= "" then
                    name = name .. "-" .. realm
                end
                if TrialChatCommon.NormalizeCharacterName(name) == senderKey then
                    return unit
                end
            end
        end
    end
end

local function hideBubble(bubble)
    bubble.fadeOut:Stop()
    bubble:Hide()
    if bubble.unit and bubblesByUnit[bubble.unit] == bubble then
        bubblesByUnit[bubble.unit] = nil
    end
end

local function createBubble(plate)
    local bubble = CreateFrame("Frame", nil, plate, "ChatBubbleTemplate")
    bubble:SetFrameLevel(plate:GetFrameLevel() + 10)
    bubble:SetIgnoreParentAlpha(true)
    bubble.String:SetPoint("BOTTOM", plate, "TOP", 0, BUBBLE_OFFSET_Y)
    -- The template leaves the tail unanchored, which stretches it over the bubble.
    bubble.Tail:ClearAllPoints()
    bubble.Tail:SetAtlas("ChatBubble-Tail", true)
    bubble.Tail:SetPoint("TOP", bubble, "BOTTOM",
        BUBBLE_TAIL_OFFSET_X, BUBBLE_TAIL_OFFSET_Y)

    bubble.fadeOut = bubble:CreateAnimationGroup()
    local fade = bubble.fadeOut:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(BUBBLE_FADE_SECONDS)
    bubble.fadeOut:SetScript("OnFinished", function()
        hideBubble(bubble)
    end)

    bubble:Hide()
    return bubble
end

function TrialChatBubbles.ShowMessage(sender, message)
    if not isBubblesEnabled() or not sender or not message then return end

    local text = strtrim(toPlainText(message))
    if text == "" then return end

    local unit = findNamePlateUnit(sender)
    local plate = unit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end

    local bubble = bubblesByPlate[plate]
    if not bubble then
        bubble = createBubble(plate)
        bubblesByPlate[plate] = bubble
    end
    if bubble.unit and bubblesByUnit[bubble.unit] == bubble then
        bubblesByUnit[bubble.unit] = nil
    end
    bubble.unit = unit
    bubblesByUnit[unit] = bubble

    bubble.String:SetWidth(BUBBLE_MAX_WIDTH)
    bubble.String:SetText(text)
    bubble.String:SetWidth(math.min(BUBBLE_MAX_WIDTH,
        math.ceil(bubble.String:GetUnboundedStringWidth())))
    bubble.fadeOut:Stop()
    bubble:SetAlpha(1)
    bubble:Show()

    bubble.messageCounter = (bubble.messageCounter or 0) + 1
    local messageCounter = bubble.messageCounter
    local seconds = math.max(BUBBLE_MIN_SECONDS,
        math.min(BUBBLE_MAX_SECONDS, #text * BUBBLE_SECONDS_PER_BYTE))
    C_Timer.After(seconds, function()
        if bubble.messageCounter == messageCounter and bubble:IsShown() then
            bubble.fadeOut:Play()
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:SetScript("OnEvent", function(_, _, unit)
    local bubble = bubblesByUnit[unit]
    if bubble then
        hideBubble(bubble)
    end
end)

SLASH_TRIALCHATBUBBLES1 = "/tcbubbles"
SlashCmdList["TRIALCHATBUBBLES"] = function()
    TrialChatDB = TrialChatDB or {}
    TrialChatDB.chatBubbles = not isBubblesEnabled()
    if not TrialChatDB.chatBubbles then
        for _, bubble in pairs(bubblesByPlate) do
            hideBubble(bubble)
        end
    end
    print("|cffff7d0a[TrialChat]|r Chat bubbles "
        .. (TrialChatDB.chatBubbles and "on" or "off") .. ".")
end
