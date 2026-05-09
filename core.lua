local addonName, ns = ...
if not iAutoPassBonusRollDB then
	iAutoPassBonusRollDB = {
		difs = {},
		encounters = {},
		instances = {},
	}
end
local db = iAutoPassBonusRollDB

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
	DevTools_Dump({spellID, effectValue, message, duration, currencyTypesID, currencyCost, currentDifficulty, displayItemID, itemContext, treasureContextLevel})
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
		}) do
		local difName, difType = GetDifficultyInfo(id)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(id), tostring(id), db.difs, "boolean", string.format("%s (%s)", difName, difType)))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(GUILD_NEWS_FILTER3)) -- Raid encounters
	--Settings.CreateSectionHeader(config, GUILD_NEWS_FILTER3) -- Raid encounters
	for _, d in ipairs({
		-- Voidspire
		{ejId = 2733, eId = 3176, jiId = 1307}, -- Imperator Averzian
		{ejId = 2734, eId = 3177, jiId = 1307}, -- Vorasius
		{ejId = 2736, eId = 3179, jiId = 1307}, -- Salhadaar
		{ejId = 2735, eId = 3178, jiId = 1307}, -- Vaelgor & Ezzorak
		{ejId = 2737, eId = 3180, jiId = 1307}, -- Lightblinded Vanguard
		{ejId = 2738, eId = 3181, jiId = 1307}, -- Crown of the Cosmos
		-- Dreamrift
		{ejId = 2795, eId = 3306, jiId = 1314}, -- Chimearus
		-- March
		{ejId = 2739, eId = 3182, jiId = 1308}, -- Belo'ren
		{ejId = 2740, eId = 3183, jiId = 1308}, -- Midnight falls

	}) do
		local encounterName = EJ_GetEncounterInfo(d.ejId)
		if not encounterName then
			EJ_SelectInstance(d.jiId)
			encounterName = EJ_GetEncounterInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.eId)
		end
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.eId), tostring(d.eId), db.encounters, "boolean", encounterName))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(DUNGEONS)) -- M+ dungeons
	--Settings.CreateSectionHeader(config, DUNGEONS) -- M+ dungeons
	for _, d in ipairs({
		{ejId = 1201, instanceId = 2526}, -- Algeth'ar Academy
		{ejId = 1300, instanceId = 2811}, -- Magisters' Terrace
		{ejId = 1315, instanceId = 2874}, -- Maisara Caverns
		{ejId = 1316, instanceId = 2915}, -- Nexus-Point Xenas
		{ejId = 278, instanceId = 658}, -- Pit of Saron
		{ejId = 945, instanceId = 1753}, -- Seat of the Triumvirate
		{ejId = 476, instanceId = 1209}, -- Skyreach
		{ejId = 1299, instanceId = 2805}, -- Windrunner Spire
	}) do
		local instanceName = EJ_GetInstanceInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.instanceId)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.instanceId), tostring(d.instanceId), db.instances, "boolean", instanceName))
	end
	Settings.RegisterAddOnCategory(config)
end

do
	local encountersToItems = {
		[3176] = 268459, -- Imperator Averzian
		[3177] = 268460, -- Vorasius
		[3179] = 268461, -- Salhadaar
		[3178] = 268462, -- Vaelgor & Ezzorak
		[3180] = 268463, -- Lightblinded Vanguard
		[3181] = 267488, -- Crown of the Cosmos
		[3306] = 268464, -- Chimearus
		[3182] = 268458, -- Belo'ren
		[3183] = 262658, -- Midnight falls
	}
	local instancesToItems = {
		[2526] = 268465, -- Algeth'ar Academy
		[2811] = 268466, -- Magisters' Terrace
		[2874] = 268473, -- Maisara Caverns
		[2915] = 268467, -- Nexus-Point Xenas
		[658] = 268468, -- Pit of Saron
		[1753] = 268469, -- Seat of the Triumvirate
		[1209] = 268470, -- Skyreach
		[2805] = 268471, -- Windrunner Spire
	}
	local difIdToContextDif = {
		[23] = 16, -- Mythic 0
		[8] = 16, -- Mythic+
		[17] = 4, -- LFR
		[14] = 3, -- Raid Normal
		[15] = 5, -- Raid Heroic
		[16] = 6, -- Raid Mythic
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
						if not contextDif then return end
						--GameTooltip:SetItemByID(268469, nil, 16, 10)
						GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
						GameTooltip:SetItemByID(encountersToItems[button.bonusRollFrame.encounterId], nil, contextDif, nil)
						GameTooltip:Show()
					end)
					button.bonusRollFrame:SetScript("OnLeave", function(self)
						GameTooltip:Hide()
					end)
				end
				button.bonusRollFrame.encounterId = encounterID
				button.bonusRollFrame:Show()
				return
			end
		end
		if not button.bonusRollFrame then return end
			button.bonusRollFrame:Hide()
			button.bonusRollFrame.encounterId = nil
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
					GameTooltip:Show()
				end)
				f:SetScript("OnLeave", function(self)
					GameTooltip:Hide()
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