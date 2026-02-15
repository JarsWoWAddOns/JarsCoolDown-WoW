local configFrame
local icons = {}
local currentStacks = {}
local chargeCooldowns = {}
local iconContainer
local currentSpec = 1
local f -- Forward declaration for event frame
local isInCombat = false -- Cached combat state

-- Per-character, per-spec saved variables
JarsCoolDownDB = JarsCoolDownDB or {}

-- Get current profile based on spec
local function GetCurrentProfile()
    local specIndex = GetSpecialization() or 1
    currentSpec = specIndex
    
    -- Initialize spec profile if it doesn't exist
    if not JarsCoolDownDB[specIndex] then
        JarsCoolDownDB[specIndex] = {
            spells = {
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false}
            },
            iconSize = 64,
            bgOpacity = 0.8,
            locked = true,
            position = nil,
            onlyInCombat = false
        }
    end
    
    -- Ensure onlyInCombat exists for existing profiles
    if JarsCoolDownDB[specIndex].onlyInCombat == nil then
        JarsCoolDownDB[specIndex].onlyInCombat = false
    end
    
    return JarsCoolDownDB[specIndex]
end

-- Reload icons when spec changes
local function ReloadIcons()
    -- Clear existing icons
    if iconContainer then
        iconContainer:Hide()
        for i = 1, 6 do
            if icons[i] then
                icons[i]:Hide()
                icons[i]:SetScript("OnUpdate", nil)
            end
        end
    end

    -- Reset state
    icons = {}
    currentStacks = {}
    chargeCooldowns = {}
    iconContainer = nil

    -- Recreate config window for new spec
    if configFrame then
        configFrame:Hide()
        configFrame = nil
    end

    -- Trigger recreation by firing the PLAYER_ENTERING_WORLD handler directly
    C_Timer.After(0.1, function()
        f:GetScript("OnEvent")(f, "PLAYER_ENTERING_WORLD")
    end)
end

local function CreateConfigWindow()
    local profile = GetCurrentProfile()
    
    configFrame = CreateFrame("Frame", "JarsCoolDownConfig", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(660, 400)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
    
    -- Update title to show current spec
    local specID, specName = GetSpecializationInfo(GetSpecialization() or 1)
    configFrame.title:SetText("Jar's Cooldowns Config - " .. (specName or "Unknown"))
    configFrame:Hide()
    
    -- Column headers
    local headerSpellID = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerSpellID:SetPoint("TOPLEFT", 30, -40)
    headerSpellID:SetText("Spell ID")
    
    local headerCooldown = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerCooldown:SetPoint("TOPLEFT", 140, -40)
    headerCooldown:SetText("Cooldown")
    
    local headerStacks = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerStacks:SetPoint("TOPLEFT", 230, -40)
    headerStacks:SetText("Stacks")
    
    local headerReset = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerReset:SetPoint("TOPLEFT", 310, -40)
    headerReset:SetText("Reset ID")
    
    local headerAlways = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerAlways:SetPoint("TOPLEFT", 430, -40)
    headerAlways:SetText("Always Show")
    
    local headerHaste = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerHaste:SetPoint("TOPLEFT", 550, -40)
    headerHaste:SetText("Haste")
    
    -- Store input boxes for save button access
    local inputBoxes = {}
    
    -- Create 6 rows of inputs
    for i = 1, 6 do
        local index = i
        local yPos = -60 - ((i - 1) * 30)
        
        inputBoxes[index] = {}
        
        -- Spell ID input
        local spellIDBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
        spellIDBox:SetSize(80, 25)
        spellIDBox:SetPoint("TOPLEFT", 20, yPos)
        spellIDBox:SetAutoFocus(false)
        spellIDBox:SetText(tostring(profile.spells[index].spellID))
        spellIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        
        -- Spell icon display next to spellID box
        local spellIcon = CreateFrame("Frame", nil, configFrame)
        spellIcon:SetSize(20, 20)
        spellIcon:SetPoint("LEFT", spellIDBox, "RIGHT", 5, 0)
        spellIcon.texture = spellIcon:CreateTexture(nil, "ARTWORK")
        spellIcon.texture:SetAllPoints()
        local iconTexture = C_Spell.GetSpellTexture(profile.spells[index].spellID)
        if iconTexture and profile.spells[index].spellID > 0 then
            spellIcon.texture:SetTexture(iconTexture)
        else
            spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        
        spellIDBox:SetScript("OnEnterPressed", function(self) 
            profile.spells[index].spellID = tonumber(self:GetText()) or 0
            
            -- Update config icon
            local texture = C_Spell.GetSpellTexture(profile.spells[index].spellID)
            if texture and profile.spells[index].spellID > 0 then
                spellIcon.texture:SetTexture(texture)
            else
                spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            -- Update main icon
            if icons[index] then
                if texture then
                    icons[index].texture:SetTexture(texture)
                end
            end
            self:ClearFocus()
        end)
        inputBoxes[index].spellIDBox = spellIDBox
        inputBoxes[index].spellIcon = spellIcon
        
        -- Cooldown input
        local cooldownBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
        cooldownBox:SetSize(70, 25)
        cooldownBox:SetPoint("TOPLEFT", 130, yPos)
        cooldownBox:SetAutoFocus(false)
        cooldownBox:SetText(tostring(profile.spells[index].cooldown))
        cooldownBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        cooldownBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].cooldown = tonumber(self:GetText()) or 0
            self:ClearFocus()
        end)
        inputBoxes[index].cooldownBox = cooldownBox
        
        -- Stacks input
        local stacksBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
        stacksBox:SetSize(60, 25)
        stacksBox:SetPoint("TOPLEFT", 220, yPos)
        stacksBox:SetAutoFocus(false)
        stacksBox:SetText(tostring(profile.spells[index].stacks))
        stacksBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        stacksBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].stacks = tonumber(self:GetText()) or 0
            self:ClearFocus()
        end)
        inputBoxes[index].stacksBox = stacksBox
        
        -- Reset Spell ID input
        local resetBox = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
        resetBox:SetSize(80, 25)
        resetBox:SetPoint("TOPLEFT", 300, yPos)
        resetBox:SetAutoFocus(false)
        resetBox:SetText(tostring(profile.spells[index].resetID))
        resetBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        
        -- Reset icon display next to resetID box
        local resetIcon = CreateFrame("Frame", nil, configFrame)
        resetIcon:SetSize(20, 20)
        resetIcon:SetPoint("LEFT", resetBox, "RIGHT", 5, 0)
        resetIcon.texture = resetIcon:CreateTexture(nil, "ARTWORK")
        resetIcon.texture:SetAllPoints()
        local iconTexture = C_Spell.GetSpellTexture(profile.spells[index].resetID)
        if iconTexture and profile.spells[index].resetID > 0 then
            resetIcon.texture:SetTexture(iconTexture)
        else
            resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        
        resetBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].resetID = tonumber(self:GetText()) or 0
            
            -- Update icon
            local texture = C_Spell.GetSpellTexture(profile.spells[index].resetID)
            if texture and profile.spells[index].resetID > 0 then
                resetIcon.texture:SetTexture(texture)
            else
                resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            self:ClearFocus()
        end)
        inputBoxes[index].resetBox = resetBox
        inputBoxes[index].resetIcon = resetIcon
        
        -- Always Show checkbox
        local alwaysCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        alwaysCheck:SetPoint("TOPLEFT", 440, yPos)
        alwaysCheck:SetChecked(profile.spells[index].alwaysShow)
        alwaysCheck:SetScript("OnClick", function(self)
            profile.spells[index].alwaysShow = self:GetChecked()
            if icons[index] then
                if currentStacks[index] and currentStacks[index] == 0 then
                    icons[index]:Show()
                else
                    if profile.spells[index].alwaysShow and profile.spells[index].spellID > 0 then
                        icons[index]:Show()
                    else
                        icons[index]:Hide()
                    end
                end
            end
        end)
        inputBoxes[index].alwaysCheck = alwaysCheck
        
        -- Haste checkbox
        local hasteCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        hasteCheck:SetPoint("TOPLEFT", 545, yPos)
        hasteCheck:SetChecked(profile.spells[index].haste)
        hasteCheck:SetScript("OnClick", function(self)
            profile.spells[index].haste = self:GetChecked()
        end)
        inputBoxes[index].hasteCheck = hasteCheck
    end
    
    -- Save button
    local saveButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 25)
    saveButton:SetPoint("BOTTOMLEFT", 150, 20)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        for i = 1, 6 do
            profile.spells[i].spellID = tonumber(inputBoxes[i].spellIDBox:GetText()) or 0
            profile.spells[i].cooldown = tonumber(inputBoxes[i].cooldownBox:GetText()) or 0
            profile.spells[i].stacks = tonumber(inputBoxes[i].stacksBox:GetText()) or 0
            profile.spells[i].resetID = tonumber(inputBoxes[i].resetBox:GetText()) or 0
            profile.spells[i].alwaysShow = inputBoxes[i].alwaysCheck:GetChecked()
            profile.spells[i].haste = inputBoxes[i].hasteCheck:GetChecked()
            
            -- Reset current stacks to max
            if profile.spells[i].stacks > 0 then
                currentStacks[i] = profile.spells[i].stacks
                chargeCooldowns[i] = {}
            else
                currentStacks[i] = 1
                chargeCooldowns[i] = {}
            end
            
            -- Update config window icons
            if inputBoxes[i].spellIcon then
                local spellTexture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if spellTexture and profile.spells[i].spellID > 0 then
                    inputBoxes[i].spellIcon.texture:SetTexture(spellTexture)
                else
                    inputBoxes[i].spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            end
            
            if inputBoxes[i].resetIcon then
                local resetTexture = C_Spell.GetSpellTexture(profile.spells[i].resetID)
                if resetTexture and profile.spells[i].resetID > 0 then
                    inputBoxes[i].resetIcon.texture:SetTexture(resetTexture)
                else
                    inputBoxes[i].resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            end
            
            -- Update icon texture if icon exists
            if icons[i] then
                local texture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if texture then
                    icons[i].texture:SetTexture(texture)
                end
                
                -- Update visibility based on Always Show
                if profile.spells[i].alwaysShow and profile.spells[i].spellID > 0 then
                    icons[i]:Show()
                elseif currentStacks[i] == 0 then
                    icons[i]:Show()
                else
                    icons[i]:Hide()
                end
            end
        end
        print("JarsCoolDown: Configuration saved!")
    end)
    
    -- Lock/Unlock button (next to save)
    local lockButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    lockButton:SetSize(80, 25)
    lockButton:SetPoint("LEFT", saveButton, "RIGHT", 20, 0)
    lockButton:SetText(profile.locked and "Unlock" or "Lock")
    lockButton:SetScript("OnClick", function(self)
        profile.locked = not profile.locked
        self:SetText(profile.locked and "Unlock" or "Lock")
        
        if iconContainer then
            if profile.locked then
                iconContainer:EnableMouse(false)
                iconContainer:SetMovable(false)
                iconContainer.background:SetColorTexture(0, 0, 0, 1)
            else
                iconContainer:EnableMouse(true)
                iconContainer:SetMovable(true)
                iconContainer.background:SetColorTexture(0.2, 0.5, 0.2, 1)
            end
        end
    end)
    
    -- Reset Position button (next to unlock)
    local resetPosButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetPosButton:SetSize(120, 25)
    resetPosButton:SetPoint("LEFT", lockButton, "RIGHT", 20, 0)
    resetPosButton:SetText("Reset Position")
    resetPosButton:SetScript("OnClick", function(self)
        profile.position = nil
        if iconContainer then
            iconContainer:ClearAllPoints()
            iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("JarsCoolDown: Position reset to center")
    end)
    
    -- Icon size slider
    local sizeSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, -250)
    sizeSlider:SetMinMaxValues(20, 100)
    sizeSlider:SetValue(profile.iconSize or 64)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider.tooltipText = "Icon size"
    sizeSlider.Text:SetText("Icon Size: " .. (profile.iconSize or 64))
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local size = math.floor(value)
        profile.iconSize = size
        self.Text:SetText("Icon Size: " .. size)
        
        -- Update icon sizes and positions if icons exist
        if iconContainer and #icons > 0 then
            local padding = 2
            local spacing = size + padding
            local fontSize = math.max(12, math.floor(size * 0.75))
            
            for i = 1, 6 do
                if icons[i] then
                    -- Resize icon
                    icons[i]:SetSize(size, size)
                    
                    -- Update font size
                    if icons[i].text then
                        icons[i].text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                    end
                    
                    -- Reposition with 2px padding
                    local row = math.floor((i - 1) / 3)
                    local col = (i - 1) % 3
                    icons[i]:ClearAllPoints()
                    icons[i]:SetPoint("TOPLEFT", col * spacing, -row * spacing)
                end
            end
            
            -- Update container size
            local containerWidth = (spacing * 3) - padding
            local containerHeight = (spacing * 2) - padding
            iconContainer:SetSize(containerWidth, containerHeight)
        end
    end)
    
    -- Background opacity slider
    local opacitySlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    opacitySlider:SetPoint("LEFT", sizeSlider, "RIGHT", 80, 0)
    opacitySlider:SetMinMaxValues(0, 1)
    opacitySlider:SetValue(profile.bgOpacity or 0.8)
    opacitySlider:SetValueStep(0.01)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider.tooltipText = "Background opacity"
    opacitySlider.Text:SetText("BG Opacity: " .. string.format("%.2f", profile.bgOpacity or 0.8))
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        profile.bgOpacity = value
        self.Text:SetText("BG Opacity: " .. string.format("%.2f", value))
        
        -- Update background opacity if it exists
        if iconContainer and iconContainer.background then
            iconContainer.background:SetAlpha(value)
        end
    end)
    
    -- Only Show in Combat checkbox
    local combatCheckLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    combatCheckLabel:SetPoint("TOPLEFT", 20, -340)
    combatCheckLabel:SetText("Only Show in Combat:")
    
    local combatCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    combatCheck:SetPoint("LEFT", combatCheckLabel, "RIGHT", 5, 0)
    combatCheck:SetChecked(profile.onlyInCombat)
    combatCheck:SetScript("OnClick", function(self)
        profile.onlyInCombat = self:GetChecked()
        -- Update icon visibility immediately
        if iconContainer then
            if profile.onlyInCombat and not isInCombat then
                iconContainer:Hide()
            else
                iconContainer:Show()
            end
        end
    end)
end

-- Create icons and handle events
f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec changed, reload icons with new profile
        ReloadIcons()
        print("JarsCoolDown: Switched to " .. (select(2, GetSpecializationInfo(GetSpecialization() or 1))) .. " profile")
        return
    end
    
    local profile = GetCurrentProfile()
    
    if event == "PLAYER_ENTERING_WORLD" then
        if not configFrame then
            CreateConfigWindow()
        end
        
        if #icons == 0 then
            -- Get saved icon size
            local size = profile.iconSize or 64
            local spacing = size + 2
            local containerWidth = (spacing * 3) - 2
            local containerHeight = (spacing * 2) - 2
            local fontSize = math.max(12, math.floor(size * 0.75))
            
            -- Create icon container
            iconContainer = CreateFrame("Frame", nil, UIParent)
            iconContainer:SetSize(containerWidth, containerHeight)
            
            -- Restore saved position or center
            if profile.position and profile.position.point and profile.position.relativePoint then
                local success = pcall(function()
                    iconContainer:SetPoint(
                        profile.position.point,
                        UIParent,
                        profile.position.relativePoint,
                        profile.position.x,
                        profile.position.y
                    )
                end)
                if not success then
                    -- Invalid position, reset to center
                    profile.position = nil
                    iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            else
                iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
            
            -- Make draggable
            iconContainer:SetMovable(true)
            iconContainer:EnableMouse(not profile.locked)
            iconContainer:RegisterForDrag("LeftButton")
            iconContainer:SetScript("OnDragStart", function(self)
                if not profile.locked then
                    self:StartMoving()
                end
            end)
            iconContainer:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                -- Save position with anchor info
                local point, _, relativePoint, x, y = self:GetPoint()
                profile.position = {
                    point = point,
                    relativePoint = relativePoint,
                    x = x,
                    y = y
                }
            end)
            
            -- Add background
            iconContainer.background = iconContainer:CreateTexture(nil, "BACKGROUND")
            iconContainer.background:SetAllPoints()
            iconContainer.background:SetColorTexture(0, 0, 0, 1)
            iconContainer.background:SetAlpha(profile.bgOpacity or 0.8)
            
            -- Create 6 icons in 3x2 grid
            for i = 1, 6 do
                local icon = CreateFrame("Frame", nil, iconContainer)
                icon:SetSize(size, size)
                
                -- Position in 3x2 grid with 2px padding
                local row = math.floor((i - 1) / 3)
                local col = (i - 1) % 3
                icon:SetPoint("TOPLEFT", col * spacing, -row * spacing)
                
                -- Spell texture
                icon.texture = icon:CreateTexture(nil, "ARTWORK")
                icon.texture:SetAllPoints()
                icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                
                -- Cooldown text
                icon.text = icon:CreateFontString(nil, "OVERLAY")
                icon.text:SetPoint("CENTER")
                icon.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                icon.text:SetText("")
                
                -- Initialize stacks
                if profile.spells[i].stacks > 0 then
                    currentStacks[i] = profile.spells[i].stacks
                else
                    currentStacks[i] = 1
                end
                chargeCooldowns[i] = {}
                
                -- OnUpdate for countdown and stack display
                icon:SetScript("OnUpdate", function(self)
                    local maxStacks = profile.spells[i].stacks
                    local spell = profile.spells[i]
                    
                    -- Check if we should hide icons based on combat status
                    if profile.onlyInCombat and not isInCombat then
                        if iconContainer then
                            iconContainer:Hide()
                        end
                        return
                    else
                        if iconContainer and not iconContainer:IsShown() then
                            iconContainer:Show()
                        end
                    end
                    
                    -- Update cooldowns and restore stacks
                    if chargeCooldowns[i] and #chargeCooldowns[i] > 0 then
                        local now = GetTime()
                        local newCooldowns = {}
                        
                        for _, endTime in ipairs(chargeCooldowns[i]) do
                            if endTime > now then
                                table.insert(newCooldowns, endTime)
                            else
                                -- Cooldown expired, restore a stack
                                if maxStacks > 0 then
                                    currentStacks[i] = math.min(currentStacks[i] + 1, maxStacks)
                                else
                                    currentStacks[i] = 1
                                end
                            end
                        end
                        
                        chargeCooldowns[i] = newCooldowns
                    end
                    
                    -- Display logic
                    if currentStacks[i] == 0 then
                        -- No stacks available - show desaturated icon with shortest cooldown
                        self.texture:SetDesaturated(true)
                        
                        if #chargeCooldowns[i] > 0 then
                            local shortest = math.huge
                            for _, endTime in ipairs(chargeCooldowns[i]) do
                                local remaining = endTime - GetTime()
                                if remaining < shortest then
                                    shortest = remaining
                                end
                            end
                            
                            if shortest < math.huge and shortest > 0 then
                                self.text:SetText(string.format("%.1f", shortest))
                            else
                                self.text:SetText("")
                                -- Edge case: cooldown just expired
                                self.texture:SetDesaturated(false)
                            end
                        else
                            self.text:SetText("")
                            -- No cooldowns left, restore color
                            self.texture:SetDesaturated(false)
                        end
                        
                        self:Show()
                    elseif currentStacks[i] > 0 then
                        -- Stacks available - show in color with stack count
                        self.texture:SetDesaturated(false)
                        
                        if maxStacks > 0 then
                            self.text:SetText(tostring(currentStacks[i]))
                        else
                            self.text:SetText("")
                        end
                        
                        -- Show/hide based on Always Show
                        if spell.alwaysShow and spell.spellID > 0 then
                            self:Show()
                        else
                            self:Hide()
                        end
                    end
                end)
                
                -- Set initial texture and visibility
                local texture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if texture then
                    icon.texture:SetTexture(texture)
                end
                
                if profile.spells[i].alwaysShow and profile.spells[i].spellID > 0 then
                    icon:Show()
                else
                    icon:Hide()
                end
                
                icons[i] = icon
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Check if this spell matches any configured spell
        for i = 1, 6 do
            local spell = profile.spells[i]
            local maxStacks = spell.stacks > 0 and spell.stacks or 1
            
            -- Check if it's a main spell cast
            if spell.spellID == spellID and spell.cooldown > 0 then
                -- Subtract a stack
                if currentStacks[i] > 0 then
                    currentStacks[i] = currentStacks[i] - 1
                end
                
                -- Add cooldown timer sequentially (not parallel)
                local startTime = GetTime()
                
                -- If there are existing cooldowns, queue after the last one
                if #chargeCooldowns[i] > 0 then
                    local latestEnd = 0
                    for _, endTime in ipairs(chargeCooldowns[i]) do
                        if endTime > latestEnd then
                            latestEnd = endTime
                        end
                    end
                    startTime = latestEnd
                end
                
                -- Apply haste reduction if checkbox is enabled
                local adjustedCooldown = spell.cooldown
                if spell.haste then
                    local hastePercent = UnitSpellHaste("player")
                    adjustedCooldown = spell.cooldown / (1 + (hastePercent / 100))
                end
                
                table.insert(chargeCooldowns[i], startTime + adjustedCooldown)
                
                if icons[i] then
                    icons[i]:Show()
                end
            end
            
            -- Check if it's a reset spell cast
            if spell.resetID == spellID and spell.resetID > 0 then
                -- Clear all cooldowns and restore full stacks
                chargeCooldowns[i] = {}
                currentStacks[i] = maxStacks
                
                if icons[i] then
                    icons[i].texture:SetDesaturated(false)
                    
                    -- Show/hide based on Always Show
                    if spell.alwaysShow and spell.spellID > 0 then
                        icons[i]:Show()
                    else
                        icons[i]:Hide()
                    end
                end
            end
        end
    end
end)

-- Slash command
SLASH_JCD1 = "/jcd"
SLASH_JCD2 = "/jarscooldown"
SlashCmdList["JCD"] = function(msg)
    msg = msg:lower():trim()
    local profile = GetCurrentProfile()
    
    if msg == "reset" then
        -- Force reset position
        profile.position = nil
        if iconContainer then
            iconContainer:ClearAllPoints()
            iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            iconContainer:Show()
        end
        print("JarsCoolDown: Position reset and frame shown")
    elseif msg == "show" then
        -- Force show the icon container
        if iconContainer then
            iconContainer:Show()
            print("JarsCoolDown: Frame shown")
        else
            print("JarsCoolDown: Frame not created yet")
        end
    else
        -- Toggle config window
        if configFrame then
            if configFrame:IsShown() then
                configFrame:Hide()
            else
                configFrame:Show()
            end
        end
    end
end

