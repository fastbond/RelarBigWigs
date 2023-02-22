
local module, L = BigWigs:ModuleDeclaration("Loatheb", "Naxxramas")

module.revision = 20048
module.enabletrigger = module.translatedName
module.toggleoptions = {"doom", "curse", "spore", "debuff", "sporecount", -1, "consumable", "graphic", "sound", "bosskill"}

L:RegisterTranslations("enUS", function() return {
	cmd = "Loatheb",

	doom_cmd = "doom",
	doom_name = "Inevitable Doom Alert",
	doom_desc = "Warn for Inevitable Doom",

	curse_cmd = "curse",
	curse_name = "Remove Curse Alert",
	curse_desc = "Warn when curses are removed from Loatheb",

	spore_cmd = "spore",
	spore_name = "Spore Alert",
	spore_desc = "Warn for Spores",

	debuff_cmd = "debuff",
	debuff_name = "Spore Debuff",
	debuff_desc = "Show icon when your spore debuff is running out",
    
    sporecount_cmd = "sporecount",
	sporecount_name = "Spore Count",
	sporecount_desc = "Add a group counter for spores(1-7)",

	doombar = "Inevitable Doom %d",
	doomwarn = "Inevitable Doom %d! %d sec to next!",
	doomwarn5sec = "Inevitable Doom %d in 5 sec!",
	doomtrigger = "afflicted by Inevitable Doom.",

	cursewarn = "Curses removed! RENEW CURSES",
	cursebar = "Remove Curse",
	cursetrigger  = "Loatheb's Curse (.+) is removed.",


	doomtimerbar = "Doom every 15sec",
	doomtimerwarn = "Doom timerchange in %s seconds!",
	doomtimerwarnnow = "Inevitable Doom now happens every 15sec!",

	cursetimerbar = "Remove Curse Timer",
	cursetimerwarn = "Curses removed, next in %s seconds!",

	sporebar = "Next Spore",

	you = "You",
	are = "are",
	fungalBloom = "Fungal Bloom",

	graphic_cmd = "graphic",
	graphic_name = "Graphical Icons",
	graphic_desc = "When checked shows graphical icons",

	sound_cmd = "sound",
	sound_name = "Sound Effects",
	sound_desc = "When checked plays sound effects",

	consumable_cmd = "consumable",
	consumable_name = "Do NOT warn raid to use consumables (A)",
	consumable_desc = "When check does NOT warn raid to use consambles over raidwarn. Requires Assistance (A)",

	shadowpot = "-- Drink Shadow Protection Potion ! --",
	bandage = "-- Use your bandages ! --",
	wrtorhs = "-- Healthstone or Whipper Root Tuber ! --",
	shadowpotandbandage = "-- Drink Shadow Protection Potion and Bandage ! --",
	noconsumable = "-- No Consumable at this time ! --",

	soundshadowpot = "Interface\\Addons\\BigWigs\\Sounds\\potion.wav",
	soundbandage = "Interface\\Addons\\BigWigs\\Sounds\\bandage.wav",
	soundwrtorhs = "Interface\\Addons\\BigWigs\\Sounds\\healthstone.wav",
	soundshadowpotandbandage = "Interface\\Addons\\BigWigs\\Sounds\\potionandbandage.wav",
	soundgoforbuff = "Interface\\Addons\\BigWigs\\Sounds\\goforbuff.wav",
} end )

local LoathebDebuff = CreateFrame( "GameTooltip", "LoathebDebuff", nil, "GameTooltipTemplate" );
LoathebDebuff:Hide()
LoathebDebuff:SetFrameStrata("TOOLTIP")
LoathebDebuff:SetOwner(WorldFrame, "ANCHOR_NONE")

local timer = {
	softEnrage = 300,
	firstDoom = 120,
	doomLong = 30,
	doomShort = 15,
	doom = 0,
	spore = 13,
	curse = 30,
	getNextSpore = 20,
}

local icon = {
	softEnrage = "Spell_Shadow_UnholyFrenzy",
	doom = "Spell_Shadow_NightOfTheDead",
	spore = "Ability_TheBlackArrow",
	curse = "Spell_Holy_RemoveCurse",
}

local syncName = {
	doom = "LoathebDoom"..module.revision,
	spore = "LoathebSporeSpawn"..module.revision,
	curse = "LoathebRemoveCurse"..module.revision,
}

local consumableslist = {L["shadowpot"],L["noconsumable"],L["bandage"],L["wrtorhs"],L["shadowpotandbandage"],L["noconsumable"],L["bandage"],L["noconsumable"],L["wrtorhs"]}
local numSpore = 0 -- how many spores have been spawned
local currentSporeGroup = 0 -- current group getting spore
local numSporeGroups = 7 -- number of groups in spore rotation.  Hardcoded at 7 
local numDoom = 0
local timeCurseWarning = 0
local _, playerClass = UnitClass("player")

function module:OnEnable()
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "Event")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "Event")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "Event")
	self:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA", "CurseEvent")

	self:ThrottleSync(10, syncName.doom)
	self:ThrottleSync(5, syncName.spore)
	self:ThrottleSync(5, syncName.curse)

	self.consumableseq = 0

	self.frameIcon = CreateFrame("Frame",nil,UIParent)

	self.frameIcon:SetFrameStrata("MEDIUM")
	self.frameIcon:SetWidth(100)
	self.frameIcon:SetHeight(100)
	self.frameIcon:SetAlpha(0.6)

	self.frameTexture = self.frameIcon:CreateTexture(nil,"BACKGROUND")

	self.frameTexture:SetTexture(nil)
	self.frameTexture:SetAllPoints(self.frameIcon)

	self.frameIcon:Hide()

	self.frameIcon2 = CreateFrame("Frame",nil,UIParent)

	self.frameIcon2:SetFrameStrata("MEDIUM")
	self.frameIcon2:SetWidth(100)
	self.frameIcon2:SetHeight(100)
	self.frameIcon2:SetAlpha(0.6)

	self.frameTexture2 = self.frameIcon2:CreateTexture(nil,"BACKGROUND")

	self.frameTexture2:SetTexture(nil)
	self.frameTexture2:SetAllPoints(self.frameIcon2)

	self.frameIcon2:Hide()
end

function module:OnSetup()
	timeCurseWarning = 0
	self.consumableseq = 0
	numSpore = 0
    currentSporeGroup = 0
	numDoom = 0
	timer.doom = timer.firstDoom

	self.frameIcon:Hide()
	self.frameIcon2:Hide()
end

function module:OnEngage()
	if UnitName("target") == "Loatheb" and (IsRaidLeader() or IsRaidOfficer()) then
		klhtm.net.sendmessage("target " .. "Loatheb")
	end
	if self.db.profile.doom then
		self:Bar(L["doomtimerbar"], timer.softEnrage, icon.softEnrage, true, "white")
		self:DelayedMessage(timer.softEnrage - 60, string.format(L["doomtimerwarn"], 60), "Attention")
		self:DelayedMessage(timer.softEnrage - 30, string.format(L["doomtimerwarn"], 30), "Attention")
		self:DelayedMessage(timer.softEnrage - 10, string.format(L["doomtimerwarn"], 10), "Urgent")
		self:DelayedMessage(timer.softEnrage - 5, string.format(L["doomtimerwarn"], 5), "Important")
		self:DelayedMessage(timer.softEnrage, L["doomtimerwarnnow"], "Important")

		self:ScheduleEvent("bwloathebdoomtimerreduce", self.SoftEnrage, timer.softEnrage)
		self:Bar(string.format(L["doombar"], numDoom + 1), timer.doom, icon.doom, true, "red")
		self:DelayedMessage(timer.doom - 5, string.format(L["doomwarn5sec"], numDoom + 1), "Urgent")
		timer.doom = timer.doomLong
	end
	self:Spore()
	self:ScheduleRepeatingEvent("bwloathebspore", self.Spore, timer.spore, self)
	self:ScheduleRepeatingEvent("bwLoathebCheckDebuff", self.CheckDebuff, 0.5, self)
end

function module:OnDisengage()
	self.frameIcon:Hide()
	self.frameIcon2:Hide()
end

function module:Event( msg )
	if string.find(msg, L["doomtrigger"]) then
		self:Sync(syncName.doom .. " " .. tostring(numDoom + 1))
	end
end

function module:CurseEvent( msg )
	if string.find(msg, L["cursetrigger"]) then
		self:Sync(syncName.curse)
	end
end

function module:BigWigs_RecvSync(sync, rest, nick)
	if sync == syncName.doom and rest then
		self:Doom(rest)
		rest = tonumber(rest)
		if rest == (self.consumableseq + 1) then
			self:ScheduleEvent("bwloathebconsumable "..tostring(self.consumableseq), self.ConsumableWarning, 11, self)
			self.consumableseq = self.consumableseq + 1
		end
		elseif sync == syncName.curse then
			self:Curse()
	end
end

function module:Doom(syncNumDoom)
	syncNumDoom = tonumber(syncNumDoom)
	if syncNumDoom then
		if syncNumDoom == (numDoom + 1) then
			numDoom = numDoom + 1
			if self.db.profile.doom then
				self:Message(string.format(L["doomwarn"], numDoom, timer.doom), "Important")
			end
			if self.db.profile.doom then
				self:Bar(string.format(L["doombar"], numDoom + 1), timer.doom, icon.doom, true, "red")
				self:DelayedMessage(timer.doom - 5, string.format(L["doomwarn5sec"], numDoom + 1), "Urgent")
			end
		end
	end
end

function module:Curse()
	if self.db.profile.curse then
		if timeCurseWarning + 5 < GetTime() then
			timeCurseWarning = GetTime()
			self:Message(L["cursewarn"], "Important")
			self:Bar(L["cursebar"], timer.curse, icon.curse, true, "yellow")
			if playerClass == "WARLOCK" then
				self:WarningSign(icon.curse, 0.7)
			end
		end
	end
end

function module:SoftEnrage()
	timer.doom = timer.doomShort
end

function module:Spore()
	numSpore = numSpore + 1
    currentSporeGroup = currentSporeGroup + 1
	if currentSporeGroup > numSporeGroups then --wrap around to group 1
		currentSporeGroup = 1
	end
    
	if self.db.profile.spore then
        local barStr = string.format(L["sporebar"], numSpore)
        if self.db.profile.sporecount then
			barStr = barStr .. " - " .. currentSporeGroup
		end
		self:Bar(barStr, timer.spore, icon.spore, true, "blue")
	end
end

function module:CheckDebuff()
	if self.db.profile.debuff then
		local debuff = strlower(L["fungalBloom"])
		local tooltip=LoathebDebuff;
		local textleft1=getglobal(tooltip:GetName().."TextLeft1");
		for i=0, 15 do
			local id = GetPlayerBuff(i,"HARMFUL")
			tooltip:SetOwner(UIParent, "ANCHOR_NONE");
			tooltip:SetPlayerBuff(id);
			buffName = textleft1:GetText();
			tooltip:Hide();
			if ( buffName and strfind(strlower(buffName), debuff )) then
				local timeleft = GetPlayerBuffTimeLeft(id)
				if timeleft < timer.getNextSpore then
					self:WarningSign(icon.spore, timer.getNextSpore)
				elseif timeleft > timer.getNextSpore then
					self:RemoveWarningSign(icon.spore)
				end
			elseif ( buffName==nil ) then
				break;
			end
		end
	end
end

function module:ConsumableWarning()
	if consumableslist[self.consumableseq] then
		if not self.db.profile.consumable then
			SendChatMessage(consumableslist[self.consumableseq], "RAID_WARNING")
			SendChatMessage(consumableslist[self.consumableseq], "SAY")
		end
		if self.db.profile.graphic then
			if consumableslist[self.consumableseq] == L["shadowpot"] then
				self.frameTexture:SetTexture("Interface\\Icons\\INV_Potion_23")
				self.frameTexture2:SetTexture(nil)
			elseif consumableslist[self.consumableseq] == L["bandage"] then
				self.frameTexture:SetTexture("Interface\\Icons\\INV_Misc_Bandage_12")
				self.frameTexture2:SetTexture(nil)
			elseif consumableslist[self.consumableseq] == L["wrtorhs"] then
				self.frameTexture:SetTexture("Interface\\Icons\\INV_Stone_04")
			elseif consumableslist[self.consumableseq] == L["shadowpotandbandage"] then
				self.frameTexture:SetTexture("Interface\\Icons\\INV_Potion_23")
				self.frameTexture2:SetTexture("Interface\\Icons\\INV_Misc_Bandage_12")
			elseif consumableslist[self.consumableseq] == L["noconsumable"] then
				self.frameTexture:SetTexture(nil)
				self.frameTexture2:SetTexture(nil)
			end
			self.frameIcon.texture = self.frameTexture
			self.frameTexture:SetTexCoord(0.0,1.0,0.0,1.0)
			self.frameIcon:SetPoint("CENTER",200,100)
			self.frameIcon:Show()
			self.frameIcon2.texture = self.frameTexture2
			self.frameTexture2:SetTexCoord(0.0,1.0,0.0,1.0)
			self.frameIcon2:SetPoint("CENTER",200,0)
			self.frameIcon2:Show()
			self:ScheduleEvent(function()
				self.frameIcon:Hide()
				self.frameIcon2:Hide()
			end, 5)
		end
		if self.db.profile.sound then
			if consumableslist[self.consumableseq] == L["shadowpot"] then
				PlaySoundFile(L["soundshadowpot"])
			elseif consumableslist[self.consumableseq] == L["bandage"] then
				PlaySoundFile(L["soundbandage"])
			elseif consumableslist[self.consumableseq] == L["wrtorhs"] then
				PlaySoundFile(L["soundwrtorhs"])
			elseif consumableslist[self.consumableseq] == L["shadowpotandbandage"] then
				PlaySoundFile(L["soundshadowpotandbandage"])
			end
		end
	end
end
