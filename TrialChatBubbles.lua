local BUBBLE_MAX_WIDTH = 220
local BUBBLE_TEXT_PADDING = 9
local BUBBLE_OFFSET_Y = 25
local BUBBLE_TAIL_SIZE = 16
local BUBBLE_TAIL_OFFSET_X = -9
local BUBBLE_TAIL_OFFSET_Y = 6
local BUBBLE_MIN_SECONDS = 4
local BUBBLE_MAX_SECONDS = 12
local BUBBLE_SECONDS_PER_BYTE = 0.05
local BUBBLE_FADE_SECONDS = 0.5
local OWN_BUBBLE_OFFSET_Y = 3
local OWN_BUBBLE_ZOOM_OFFSET = 480
local OWN_BUBBLE_MIN_ZOOM = 1
local MAX_NAMEPLATES = 40

TrialChatBubbles = {}

local bubblesByPlate = {}
local bubblesByUnit = {}
local ownBubble

local function isBubblesEnabled()
    return not (TrialChatDB and TrialChatDB.chatBubbles == false)
end

local function isOwnBubbleEnabled()
    return isBubblesEnabled()
        and not (TrialChatDB and TrialChatDB.ownChatBubble == false)
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

local function createBubble(parent)
    local bubble = CreateFrame("Frame", nil, parent, "ChatBubbleTemplate")
    bubble:SetFrameLevel(parent:GetFrameLevel() + 10)
    bubble:SetIgnoreParentAlpha(true)
    -- Nameplates are scaled down (and shrink with distance); Blizzard's own
    -- bubbles live on the WorldFrame, so match its scale instead.
    bubble:SetIgnoreParentScale(true)
    -- The template leaves the tail unanchored, which stretches it over the
    -- bubble. Blizzard's bubbles draw it at a quarter of its atlas size.
    bubble.Tail:ClearAllPoints()
    bubble.Tail:SetAtlas("ChatBubble-Tail")
    bubble.Tail:SetSize(BUBBLE_TAIL_SIZE, BUBBLE_TAIL_SIZE)
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

local function showBubble(bubble, text)
    bubble:SetScale(WorldFrame:GetEffectiveScale())
    bubble.String:SetWidth(BUBBLE_MAX_WIDTH)
    bubble.String:SetText(text)
    bubble.String:SetWidth(math.min(BUBBLE_MAX_WIDTH,
        math.ceil(bubble.String:GetUnboundedStringWidth()) + BUBBLE_TEXT_PADDING))
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
        bubble.String:SetPoint("BOTTOM", plate, "TOP", 0, BUBBLE_OFFSET_Y)
        bubblesByPlate[plate] = bubble
    end
    if bubble.unit and bubblesByUnit[bubble.unit] == bubble then
        bubblesByUnit[bubble.unit] = nil
    end
    bubble.unit = unit
    bubblesByUnit[unit] = bubble

    showBubble(bubble, text)
end

-- Your own character has no nameplate and addons can't ask where it is on
-- screen. The camera orbits your character's head, so the head is usually
-- near the middle of the screen; keep the bubble just above that spot and
-- bring it closer as the camera zooms out.
local function updateOwnBubblePosition(bubble)
    local zoom = GetCameraZoom()
    if zoom == bubble.zoom then return end
    bubble.zoom = zoom

    if zoom < OWN_BUBBLE_MIN_ZOOM then
        hideBubble(bubble)
        return
    end
    bubble.String:ClearAllPoints()
    bubble.String:SetPoint("BOTTOM", WorldFrame, "CENTER", 0,
        OWN_BUBBLE_OFFSET_Y + OWN_BUBBLE_ZOOM_OFFSET / zoom)
end

function TrialChatBubbles.ShowOwnMessage(message)
    if not isOwnBubbleEnabled() or not message then return end
    if GetCameraZoom() < OWN_BUBBLE_MIN_ZOOM then return end

    local text = strtrim(toPlainText(message))
    if text == "" then return end

    if not ownBubble then
        ownBubble = createBubble(WorldFrame)
        ownBubble:SetScript("OnUpdate", updateOwnBubblePosition)
    end
    ownBubble.zoom = nil
    updateOwnBubblePosition(ownBubble)
    showBubble(ownBubble, text)
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
SlashCmdList["TRIALCHATBUBBLES"] = function(msg)
    TrialChatDB = TrialChatDB or {}
    if strlower(strtrim(msg or "")) == "self" then
        TrialChatDB.ownChatBubble = TrialChatDB.ownChatBubble == false
        if not TrialChatDB.ownChatBubble and ownBubble then
            hideBubble(ownBubble)
        end
        print("|cffff7d0a[TrialChat]|r Chat bubble over your own character "
            .. (TrialChatDB.ownChatBubble and "on" or "off") .. ".")
        return
    end

    TrialChatDB.chatBubbles = not isBubblesEnabled()
    if not TrialChatDB.chatBubbles then
        for _, bubble in pairs(bubblesByPlate) do
            hideBubble(bubble)
        end
        if ownBubble then
            hideBubble(ownBubble)
        end
    end
    print("|cffff7d0a[TrialChat]|r Chat bubbles "
        .. (TrialChatDB.chatBubbles and "on" or "off") .. ".")
end
