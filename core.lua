local addonName, ns = ...
if not iAutoPassBonusRollDB then
	iAutoPassBonusRollDB = {
		difs = {},
		encounters = {},
		instances = {},
	}
end
local db = iAutoPassBonusRollDB
db.notes = db.notes or { encounters = {}, instances = {} } -- encounters: journal encounter id, instances: map instance id
do
	local currentSeason = 1202 -- expansion + season
	if not db.currentSeason then
		db.currentSeason = currentSeason
	elseif db.currentSeason < currentSeason then -- clean up
		wipe(db.notes.encounters)
		wipe(db.notes.instances)
		-- TBA clean up db, popup some message saying it, maybe ask if difId options should be reset or not
		db.currentSeason = currentSeason
	end
end
local addon = CreateFrame('Frame')
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function ns.ShouldAutoPassEncounter(spellID)
	local _, encounterId = GetJournalInfoForSpellConfirmation(spellID)
	return encounterId and db.encounters[tostring(encounterId)]
end

function ns.ShouldAutoPassDifficulty(difId)
	return difId and db.difs[tostring(difId)]
end

function ns.ShouldAutoPassInstance(instanceId)
	return instanceId and db.instances[tostring(instanceId)]
end

do -- Notes
	local editor
	function ns.ShowNoteEditor(anchor, kind, key, title)
		if not editor then
			editor = CreateFrame("EditBox", nil, EncounterJournal, "InputBoxTemplate")
			editor:SetSize(200, 20)
			editor:SetFrameStrata("DIALOG")
			editor:SetAutoFocus(true)
			editor:SetMaxLetters(80)
			editor.title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			editor.title:SetPoint("BOTTOMLEFT", editor, "TOPLEFT", -5, 2)
			editor:SetScript("OnEnterPressed", function(self)
				local text = strtrim(self:GetText())
				db.notes[self.kind][self.key] = text ~= "" and text or nil
				self:Hide()
			end)
			editor:SetScript("OnEscapePressed", function(self) self:Hide() end)
			editor:SetScript("OnEditFocusLost", function(self) self:Hide() end)
			EncounterJournal:HookScript("OnHide", function() editor:Hide() end)
		end
		-- kind/key are stored now, boss buttons get recycled by the scrollbox
		editor.kind, editor.key = kind, key
		editor.title:SetText(title)
		editor:ClearAllPoints()
		editor:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
		editor:SetText(db.notes[kind][key] or "")
		editor:Show()
		editor:SetFocus()
		editor:HighlightText()
	end
	function ns.OpenNoteMenu(owner, kind, key, title)
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle(title)
			root:CreateButton("Edit note", function()
				ns.ShowNoteEditor(owner, kind, key, title)
			end)
			local clear = root:CreateButton("Clear note", function()
				db.notes[kind][key] = nil
				if editor and editor:IsShown() and editor.kind == kind and editor.key == key then
					editor:Hide()
				end
			end)
			clear:SetEnabled(db.notes[kind][key] ~= nil)
		end)
	end
	function ns.AddNoteTooltipLines(kind, key)
		local note = key and db.notes[kind][key]
		if note then
			GameTooltip:AddLine("Note: " .. note, 1, 1, 1, true)
		end
		GameTooltip:AddLine("Right-click for note options", 0.5, 0.5, 0.5)
	end
end

function ns.PassBonusRoll(spellId, reason)
	print(string.format('|cffffff00Reason for passing bonus roll: "%s".|r', reason))
	DeclineSpellConfirmationPrompt(spellId)
end
addon:RegisterEvent("SPELL_CONFIRMATION_PROMPT")
function addon:SPELL_CONFIRMATION_PROMPT(spellID, effectValue, message, duration, currencyTypesID, currencyCost, currentDifficulty, displayItemID, itemContext, treasureContextLevel)
	if currencyTypesID ~= 3418 then return end -- Nebulous Voidcore
	-- difficulty from the event doesnt match what we actually want, so check difficultyId from GetInstanceInfo instead
	local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
	if ns.ShouldAutoPassDifficulty(difficultyID) then
		ns.PassBonusRoll(spellID, "DifficultyId")
		return
	end
	if ns.ShouldAutoPassInstance(instanceID) then
		ns.PassBonusRoll(spellID, "InstanceId")
		return
	end
	if ns.ShouldAutoPassEncounter(spellID) then
		ns.PassBonusRoll(spellID, "EncounterId")
		return
	end
	--DevTools_Dump({spellID, effectValue, message, duration, currencyTypesID, currencyCost, currentDifficulty, displayItemID, itemContext, treasureContextLevel})
	--DevTools_Dump({GetJournalInfoForSpellConfirmation(spellID)})
end

do -- Options
	local config, configLayout = Settings.RegisterVerticalLayoutCategory(addonName)
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(	"All of these settings are character specific.\nIf any of these match, bonus roll will automatically be passed."))
	Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, "HideTooltipButtons", "HideTooltipButtons", db, "boolean", "Hide Buttons for Tooltips (requires reload)"))
	Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, "0", "0", db.difs, "boolean", BUG_CATEGORY2)) -- Outdoor Zones
	for _, id in ipairs({
		208, -- Delves
		24, -- Dungeon Timewalking
		1, -- Normal dungeon
		2, -- Heroic dungeon
		23, -- Mythic 0
		8, -- Mythic+
		33, -- Raid Timewalking
		17, -- LFR
		14, -- Raid Normal
		15, -- Raid Heroic
		16, -- Raid Mythic
		233, -- Raid Mythic Flex
		}) do
		local difName, difType = GetDifficultyInfo(id)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(id), tostring(id), db.difs, "boolean", string.format("%s (%s)", difName, difType)))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(GUILD_NEWS_FILTER3)) -- Raid encounters
	--Settings.CreateSectionHeader(config, GUILD_NEWS_FILTER3) -- Raid encounters
	for _, d in ipairs({
		{ejId = 2888, eId = 3470, jiId = 1320}, -- Soulcoiler Nek'zali
		{ejId = 2874, eId = 3445, jiId = 1320}, -- Entombed Sentinels
		{ejId = 2894, eId = 3497, jiId = 1320}, -- Tortollan Explorers
		{ejId = 2882, eId = 3455, jiId = 1320}, -- Vashnik
		{ejId = 2871, eId = 3420, jiId = 1320}, -- Sszorak
		{ejId = 2887, eId = 3421, jiId = 1320}, -- The Twin Fangs
		{ejId = 2883, eId = 3429, jiId = 1320}, -- The Coiled Altar		
		{ejId = 2895, eId = 3492, jiId = 1320}, -- Ula'tek

		{ejId = 2849, eId = 3379, jiId = 1317}, -- Nymrissa Wavecaller

		{ejId = 2896, eId = 3513,  jiId = 1324}, -- Kith'ix
	}) do
		local encounterName = EJ_GetEncounterInfo(d.ejId)
		if not encounterName then
			EJ_SelectInstance(d.jiId)
			encounterName = EJ_GetEncounterInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.eId)
		end
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.ejId), tostring(d.ejId), db.encounters, "boolean", encounterName))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(DUNGEONS)) -- M+ dungeons
	--Settings.CreateSectionHeader(config, DUNGEONS) -- M+ dungeons
	for _, d in ipairs({
		{ejId = 1322, instanceId = 2993}, -- Altar of Fangs
		{ejId = 1311, instanceId = 2825}, -- Den of Nalorakk
		{ejId = 1304, instanceId = 2813}, -- Murder Row
		{ejId = 1309, instanceId = 2859}, -- The Blinding Vale
		{ejId = 1313, instanceId = 2923}, -- Voidscar Arena
		{ejId = 1041, instanceId = 1762}, -- Kings' Rest
		{ejId = 1202, instanceId = 2521}, -- Ruby Life Pools
		{ejId = 1030, instanceId = 1877}, -- Temple of Sethraliss
	}) do
		local instanceName = EJ_GetInstanceInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.instanceId)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.instanceId), tostring(d.instanceId), db.instances, "boolean", instanceName))
	end
	Settings.RegisterAddOnCategory(config)
end

do
	local encountersToItems = {
		[3470] = 278285, -- Soulcoiler Nek'zali
		[3445] = 278283, -- Entombed Sentinels
		[3497] = 278286, -- Tortollan Explorers
		[3455] = 278287, -- Vashnik
		[3420] = 278288, -- Sszorak
		[3421] = 278289, -- The Twin Fangs
		[3429] = 278290, -- The Coiled Altar		
		[3492] = 278284, -- Ula'tek

		[3379] = 274708, -- Nymrissa Wavecaller
		[3513] = 286019, -- Kith'ix
	}
	local instancesToItems = {
		[2993] = 279618, -- Altar of Fangs
		[2825] = 279620, -- Den of Nalorakk
		[2813] = 279623, -- Murder Row
		[2859] = 279619, -- The Blinding Vale
		[2923] = 279625, -- Voidscar Arena
		[1762] = 279621, -- Kings' Rest
		[2521] = 279622, -- Ruby Life Pools
		[1877] = 279624, -- Temple of Sethraliss
	}
	local difIdToContextDif = { -- https://wago.tools/db2/Difficulty - ItemContext
		[23] = 16, -- Mythic 0
		[8] = 16, -- Mythic+
		[17] = 94, -- LFR
		[14] = 93, -- Raid Normal
		[15] = 95, -- Raid Heroic
		[16] = 96, -- Raid Mythic
		[233] = 96, -- Raid Mythic Flex
	}
	local encountersToTreasureLevel = { -- https://wago.tools/db2/DungeonEncounter - ItemSequenceLevel
		[3470] = 1, -- Soulcoiler Nek'zali
		[3445] = 2, -- Entombed Sentinels
		[3497] = 2, -- Tortollan Explorers
		[3455] = 3, -- Vashnik
		[3420] = 3, -- Sszorak
		[3421] = 3, -- The Twin Fangs
		[3429] = 4, -- The Coiled Altar		
		[3492] = 4, -- Ula'tek

		[3379] = 1, -- Nymrissa Wavecaller
		
		[3513] = 3, -- Kith'ix
	}
	local function encounterHook(self, button, data)
		if data.bossID then
			local encounterID, instanceID = select(7, EJ_GetEncounterInfo(data.bossID))
			if encounterID and encountersToItems[encounterID] then
				if not button.bonusRollFrame then
					button.bonusRollFrame = CreateFrame("Frame", nil, button)
					button.bonusRollFrame:SetSize(20,20)
					button.bonusRollFrame.tex = button.bonusRollFrame:CreateTexture(nil, "OVERLAY")
					button.bonusRollFrame.tex:SetAllPoints(button.bonusRollFrame)
					button.bonusRollFrame.tex:SetTexture(7658128)
					button.bonusRollFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
					button.bonusRollFrame:SetScript("OnEnter", function(self)
						if not (button.bonusRollFrame.encounterId and encountersToItems[button.bonusRollFrame.encounterId]) then return end
						local difId = EJ_GetDifficulty()
						local contextDif = difIdToContextDif[difId]
						--GameTooltip:SetItemByID(268469, nil, 16, 10)
						GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
						if contextDif then
							GameTooltip:SetItemByID(encountersToItems[button.bonusRollFrame.encounterId], nil, contextDif, 0)
						end
						ns.AddNoteTooltipLines("encounters", button.bonusRollFrame.journalEncounterId)
						GameTooltip:Show()
					end)
					button.bonusRollFrame:SetScript("OnLeave", function(self)
						GameTooltip:Hide()
					end)
					button.bonusRollFrame:SetScript("OnMouseUp", function(self, mouseButton)
						if mouseButton ~= "RightButton" then return end
						local journalEncounterId = button.bonusRollFrame.journalEncounterId
						if not journalEncounterId then return end
						GameTooltip:Hide()
						ns.OpenNoteMenu(self, "encounters", journalEncounterId, EJ_GetEncounterInfo(journalEncounterId) or UNKNOWN)
					end)
				end
				button.bonusRollFrame.encounterId = encounterID
				button.bonusRollFrame.journalEncounterId = data.bossID
				button.bonusRollFrame:Show()
				return
			end
		end
		if not button.bonusRollFrame then return end
			button.bonusRollFrame:Hide()
			button.bonusRollFrame.encounterId = nil
			button.bonusRollFrame.journalEncounterId = nil
	end
	local function instanceHook()
		local instanceId = select(10, EJ_GetInstanceInfo())
		if instanceId and instancesToItems[instanceId] then
			if not EncounterJournal.encounter.bonusRollFrame then
				EncounterJournal.encounter.bonusRollFrame = CreateFrame("Frame", nil, EncounterJournal.encounter)
				local f = EncounterJournal.encounter.bonusRollFrame
				f:SetSize(20,20)
				f.tex = f:CreateTexture(nil, "OVERLAY")
				f.tex:SetAllPoints(f)
				f.tex:SetTexture(7658128)
				f:SetPoint("TOPRIGHT", EncounterJournalEncounterFrameInfoLeftHeaderShadow, "TOPRIGHT", -5, -5)
				f:SetScript("OnEnter", function(self)
					local instanceId = select(10, EJ_GetInstanceInfo())
					if not (instanceId and instancesToItems[instanceId]) then return end
					GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
					GameTooltip:SetItemByID(instancesToItems[instanceId], nil, 16, 10)
					ns.AddNoteTooltipLines("instances", instanceId)
					GameTooltip:Show()
				end)
				f:SetScript("OnLeave", function(self)
					GameTooltip:Hide()
				end)
				f:SetScript("OnMouseUp", function(self, mouseButton)
					if mouseButton ~= "RightButton" then return end
					local instanceName, _, _, _, _, _, _, _, _, instanceId = EJ_GetInstanceInfo()
					if not (instanceId and instancesToItems[instanceId]) then return end
					GameTooltip:Hide()
					ns.OpenNoteMenu(self, "instances", instanceId, instanceName or UNKNOWN)
				end)
			end
			EncounterJournal.encounter.bonusRollFrame:Show()
			return
		end
		if EncounterJournal.encounter.bonusRollFrame then
			EncounterJournal.encounter.bonusRollFrame:Hide()
		end
	end
	if not db.HideTooltipButtons then
		addon:RegisterEvent("ADDON_LOADED")
	end
	function addon:ADDON_LOADED(an)
		if an == "Blizzard_EncounterJournal" then
			C_Timer.After(1, function()
				local scrollBox = EncounterJournalEncounterFrameInfo.BossesScrollBox
				local view = scrollBox:GetView()
				view:RegisterCallback(ScrollBoxListViewMixin.Event.OnAcquiredFrame, encounterHook, addon)
			end)
			hooksecurefunc("EncounterJournal_DisplayInstance", instanceHook)
		end
	end
end

do -- Bonus roll popup note
	local function getNote()
		-- encounter notes are raids, instance notes are 5mans, so only one can match
		local encounterID = BonusRollFrame.encounterID
		if encounterID and db.notes.encounters[encounterID] then
			return db.notes.encounters[encounterID]
		end
		local instanceID = select(8, GetInstanceInfo())
		return instanceID and db.notes.instances[instanceID]
	end
	local textFrame
	hooksecurefunc("BonusRollFrame_StartBonusRoll", function(spellID)
		local frame = BonusRollFrame
		if not (frame.state == "prompt" and frame.spellID == spellID) then return end
		if not textFrame then
			-- parented to PromptFrame so it hides with the popup and when it switches to rolling state
			textFrame = CreateFrame("Frame", nil, frame.PromptFrame)
			textFrame:SetAllPoints(frame.PromptFrame)
			textFrame.text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			textFrame.text:SetTextColor(1, 1, 1)
			local font, size = textFrame.text:GetFont()
			textFrame.text:SetFont(font, size, "OUTLINE")
			textFrame.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
			textFrame.text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
			textFrame.text:SetJustifyH("LEFT")
			textFrame.text:SetWordWrap(false)
		end
		-- own frame above the timer statusbar so the text isn't drawn under it
		textFrame:SetFrameLevel(math.max(frame:GetFrameLevel(), frame.PromptFrame.Timer:GetFrameLevel()) + 5)
		local note = getNote()
		if note then
			textFrame.text:SetText(note)
			textFrame:Show()
		else
			textFrame:Hide()
		end
	end)
end

--[[
/script BonusRollFrame_StartBonusRoll(1, "", 60, 3418, 2, 16)
/script BonusRollFrame_CloseBonusRoll()
--]]