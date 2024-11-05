-- Author      : Casta (Going to Death, Turtle-WOW)
-- Create Date : 11/14/2023 12:29:49 AM

-- место для записи замен в 2х мерный массив
-- ключ массива - Альт игрока в момент убийства босса, main - имя игрока гильдии Going to Death, 
-- которому начисляется PP и желательно вне текущего рейда.
local nicknameChanges = {}
--nicknameChanges["Madarra"] = {main = 'Casta', status = nil}--для отладки
--//конец блока записи замен

GlobalOperation = ""
SortField = "pp"--сортировка по умолчанию по progress-points
AccessInstances = {}
LastEnteredValue = 0
local StrOptionYes = "да"
local StrOptionNo = "нет"

StaticPopupDialogs["CONFIRM_ADD"] = {	
	text =  "|cffa5ffb4Внести указанное количество progress-points|r `|cff00ff7f%s|r` |cffa5ffb4?|r",
	button1 = "|cffa5ffb4Да, внести!|r",
	button2 = "Нет, не нужно!",
	OnAccept = function()		
		Button1_OnClick('add')
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["CONFIRM_REMOTE"] = {
	text = "|cffffa5a5Снять указанное количество progress-points|r |cffff0000%s|r |cffffa5a5?|r",
	button1 = "|cffffa5a5Да, удалить!|r",
	button2 = "Нет, не нужно!",
	OnAccept = function()
		Button1_OnClick('remote')
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function Frame1_OnLoad()
	--установим массив разрешенных зон для проверки прогресс-рола, где ключ индекс и значение = название текущей локации
	GTD_SetZones()	
	SLASH_GTD1 = "/gtd";	
	SlashCmdList["GTD"] = function(msg)		
		GTDA_StartSettings()
		if msg == "help" then
			GTD_Help();		
		else
			GTD_customOperation(msg)				
		end
	end
end

function HelpButton_OnClick()
	GTD_Help();
end

function ToInteger(number)
    return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
end

function Button1_OnClick(operation)	
	GTD_setStatusesOfNil();
	GlobalOperation = operation;
	local enteredValue = EnteredValue:GetNumber()
	LastEnteredValue = EnteredValue:GetNumber()    
	local enteredName = EnteredName:GetText()
	local _isModifyNote = nil
	local _getNumRaidMembers = GetNumRaidMembers()
    if _getNumRaidMembers == 0 then
		print("Вы не в рейде!")
	elseif enteredName ~= "" then
		GTD_insertPointOneUser(enteredValue, enteredName, operation)
	else
		for y = 1, GetNumGuildMembers(1) do
			local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(y);
			
			for i = 1, GetNumRaidMembers() do
				local unit = 'raid' .. i;
				local who = UnitName(unit);
				
				who = GTD_usersChanges(who); --автозамена игрока на мейна в гильдии		

				if who == name then
					
					if type(tonumber(officernote)) == "number" then
						if operation == "add" then
							GuildRosterSetOfficerNote(y, tonumber(officernote) + enteredValue);						
						elseif operation == "remote" then
							local _remote = tonumber(officernote) - enteredValue;
							if _remote < 0 then
								GuildRosterSetOfficerNote(y, 0)
							else 
								GuildRosterSetOfficerNote(y, _remote);
							end
						end
					else
						GuildRosterSetOfficerNote(y, tonumber(enteredValue));
					end
					_isModifyNote = 1;
				end
			end	
		end
		--анонс рейду операций начисления и списания
		if _isModifyNote == 1 then
			local _curText = ""	
			if operation == "add" then				
				_curText = GTDA_GetTextAnnoAddedPP(enteredValue)
			elseif operation == "remote" then
				_curText = "У всех кто в рейде списывается " .. enteredValue .. " progress-point!";		
			end			
			
			if IsRaidLeader() == 1 then
				_raidChat = "RAID_WARNING"
			else
				_raidChat = "RAID"
			end

			SendChatMessage("\124cff00ff00\124Hitem: 19:0:0:0:0:0:0:0\124h".. _curText .."\124h\124r", _raidChat)					
			if GTDA_WISPER_PP == 1 then
				SendChatMessage(_curText, "WHISPER", nil, UnitName("player"))		
			end	
		end
	end	
	GlobalOperation = "";
	Frame1:Hide();
	RatingFrame:Hide()
end

function GTDA_GetTextAnnoAddedPP(pp)
	return "Всем кто в рейде начисляется " .. tostring(pp) .. " progress-point!"
end

function GTD_Help()
	DEFAULT_CHAT_FRAME:AddMessage("Аддон `gtd_admin` гильдии Going to Death. Предназначен для внесения progress-points за убийство босса, закрытие рейда или еще какую-нибудь активность.",1,1,0);
	DEFAULT_CHAT_FRAME:AddMessage("Список команд:",0,1,0);
	DEFAULT_CHAT_FRAME:AddMessage("/gtd - открытие или закрытие окна админки.",1,1,1);
	DEFAULT_CHAT_FRAME:AddMessage("/gtd help - вызов справки.",1,1,1);
	DEFAULT_CHAT_FRAME:AddMessage("/gtd [add||remote] [progress-point] [nickname] - Начисление или списание очков у конкретного игрока. Данная операция, так-же, возможна в окне аддона.",1,1,1);
	DEFAULT_CHAT_FRAME:AddMessage("/gtd decay [integer] - Срез у всех игроков progress-points в процентах (целое число).",1,1,1);
	DEFAULT_CHAT_FRAME:AddMessage("Впоследствии, планируется автоматизация процесса начисления.", 1,1,0);
	DEFAULT_CHAT_FRAME:AddMessage("Об ошибка этого аддона, пожалуйста, сообщите Casta (Going to Death. Turtle-WOW).",1,1,0);
end

--замена альта ника игрока на ник игрока мейна (должен быть в гильдии)
--для получения PP мейну вместо идущего альта.
function GTD_usersChanges(nickname)	
	local _anno = "";
	for i, val in pairs(nicknameChanges) do			
		if i == nickname then			
			if nicknameChanges[i].status == nil then
				if GlobalOperation == "add" then
					_anno = "начислено";
				elseif GlobalOperation == "remote" then
					_anno = "удалено у";
				end
				nicknameChanges[i].status = 1;
				SendChatMessage("\124cff99ff00\124Hitem: 19:0:0:0:0:0:0:0\124h".."Вместо `".. nickname .."` будет " .. _anno .. " `" .. nicknameChanges[i].main .. "`...".."\124h\124r", "RAID")
			end
			return nicknameChanges[i].main;
		end		
	end
	return nickname;
end

--обнуляем информацию о рассылке анонса о заменах
--status = nil означает, что рассылка не была. это нужно для повторного анонса о заменах при следующих записях
function GTD_setStatusesOfNil()
	for i, val in pairs(nicknameChanges) do	
		nicknameChanges[i].status = nil
	end
end

function GTD_customOperation(msg)	
	local _,_,cmd, args, unitname = string.find(msg, "%s?(%a+)%s?(%d+)%s?(.*)")		
	if cmd == "decay" and tonumber(args) ~= nil then
		GTD_Decay(args)
	elseif tonumber(args) ~= nil and unitname ~= "" then
		if cmd == "add" or cmd == "remote" then
			GTD_insertPointOneUser(args, unitname, cmd)		
		end		
	elseif (cmd == "add" or cmd == "remote") and tonumber(args) ~= nil then
		print("Не хватает имени игрока. /gtd ".. cmd .." " .. args .. " [имя_игрока]")		
	else 
		if Frame1:IsShown() then 
			Frame1:Hide()
			RatingFrame:Hide()
		else 
			Frame1:Show();
		end		
	end	
end

--ввод в поле *имя* имя игрока с таргета
function GTD_SetNameFromTarget()
	local _name = UnitName("target")
	if _name ~= nil and UnitIsPlayer("target") == 1 then
		EnteredName:SetText(tostring(_name))		
	elseif _name ~= nil and UnitIsPlayer("target") == nil then
		print("Выбранная цель не является игроком!")
	else
		print("Необходимо выбрать игрока в таргет.")
	end	
end

--функция для ввода ПП только одному игроку. через поле: `Имя`
function GTD_insertPointOneUser(enteredValue, enteredName, operation)
	GlobalOperation = operation
	
	--автозамена
	enteredName = GTD_usersChanges(enteredName)
	
	local _isModifyNote = 0
	for y = 1, GetNumGuildMembers(1) do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(y);
		if name == enteredName then
			if type(tonumber(officernote)) == "number" then
				if operation == "add" then
					GuildRosterSetOfficerNote(y, tonumber(officernote) + enteredValue);
				elseif operation == "remote" then
					local _remote = tonumber(officernote) - enteredValue;
					if _remote < 0 then
						GuildRosterSetOfficerNote(y, 0)
					else 
						GuildRosterSetOfficerNote(y, _remote);
					end
				end
			else 									
				GuildRosterSetOfficerNote(y, tonumber(enteredValue));
			end
			_isModifyNote = 1
		end		
	end	
	
	if _isModifyNote == 1 then
		local _curText = "";
		if operation == "add" then
			_curText = "Начислено `" .. enteredName .. "` " .. enteredValue .. " progress-point!";		
		elseif operation == "remote" then
			_curText = "Списано у `" .. enteredName.. "` " .. enteredValue .. " progress-point!";		
		end
		
		if (GetNumRaidMembers() >= 1) then			
			SendChatMessage("\124cff00ff88\124Hitem: 19:0:0:0:0:0:0:0\124h".. _curText .."\124h\124r", "RAID_WARNING")	
		else
			print("\124cff00ff88\124Hitem: 19:0:0:0:0:0:0:0\124h".. _curText .."\124h\124r")
		end
		if GTDA_WISPER_PP == 1 then
			SendChatMessage(_curText, "WHISPER", nil, UnitName("player"));
		end	
	
	else 
		print("`" .. tostring(enteredName) .. "` не найден или не состоит в гильдии!")
	end		
end

--возвращает очки игроку после списания в процентах (procents)
function GTD_CalcDecayPlayer(procents, officerNote)  
  local _getInteger = tonumber(string.format("%.0f", officerNote))
  local _getFloat = tonumber(officerNote) - _getInteger
  local _getDecay = _getInteger - (_getInteger / 100 * procents)
  return _getDecay + _getFloat
end

--списание по декей у всей гильдии
function GTD_Decay(procents)
	local _count = 0	
	for y = 1, GetNumGuildMembers(1) do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(y);
		
		if level == 60 and type(tonumber(officernote)) == "number" then
			GuildRosterSetOfficerNote(y, GTD_CalcDecayPlayer(procents,officernote))
			_count = _count + 1
		end
	end
	if _count > 0 then
		SendChatMessage("\124c00aaff00\124Hitem: 19:0:0:0:0:0:0:0\124h".. "Списание " .. " ".. procents.."% progress-points." .."\124h\124r", "GUILD")	
	end
end

--блок инициализации фрейма рейтинга
RatingFrame = CreateFrame("Frame", "ratingFrame", UIParent)
RatingFrame:SetBackdrop({
	  bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
	  edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
	  tile=1, tileSize=32, edgeSize=32, 
	  insets={left=11, right=12, top=12, bottom=11}
})

RatingFrame:SetWidth(270)
RatingFrame:SetHeight(300)
RatingFrame:SetPoint("CENTER", -200, 0)

-- Create the scrolling parent frame and size it to fit inside the texture
local scrollFrame = CreateFrame("ScrollFrame", "scrollFrame", RatingFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 13, -13)
scrollFrame:SetPoint("BOTTOM", 0, 11)
scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)

eb = CreateFrame("EditBox", nil, scrollFrame)
eb:SetMultiLine(true)
eb:SetFontObject(ChatFontNormal)
eb:SetWidth(230)

scrollFrame:SetScrollChild(eb)

RatingFrame:Hide()
--конец фрейма

--открытие или закрытие окна рейтинга
function GTD_OpenRatingScrollFrame()	
	if RatingFrame:IsShown() then
		RatingFrame:Hide()
	else
		GTD_GetListRaiting()
		RatingFrame:Show()
	end	
end

--формирование данный рейтинга игроков гильдии
function GTD_GetListRaiting()
	local formula = GTD_GetDigitsF()	
	local players = {}
	local textRating = ""
	for y = 1, GetNumGuildMembers(1) do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(y);
		if type(tonumber(officernote)) == "number" then
			table.insert(players, {name, tonumber(officernote), rank})			
		end			
	end
   
	local tempPlayers = {}
	tempPlayers = players
	if SortField == nil or SortField == "pp" then
		table.sort(tempPlayers, function(a, b) return a[2] < b[2] end)
		
	elseif SortField == "name" then
		table.sort(tempPlayers, function(a, b) return a[1] > b[1] end)
		
	end
    
	local countString = table.getn(tempPlayers)
	
	eb:SetHeight(countString*14)--установим высоту скролла
	
	local _min, _max
	for x = 1, countString do 
		_min = math.floor(tempPlayers[x][2]*formula[1])
		if _min < 1 then
			_min = 1
		end
		_max = math.floor(tempPlayers[x][2]*formula[2]+100)
		if SortField == "pp" then
			textRating = string.format("|cff00ff7f%s|r |cff0000aa- - ->|r %s (%s)   |cffFFF569(%s-%s)|r\r", tempPlayers[x][2], tempPlayers[x][1], tempPlayers[x][3], tostring(_min), tostring(_max)) .. textRating
		elseif SortField == "name" then
			textRating = string.format("|cff00ff7f%s (%s)|r |cff0000aa<- - -|r %s   |cffFFF569(%s-%s)|r\r", tempPlayers[x][1], tempPlayers[x][3], tempPlayers[x][2], tostring(_min), tostring(_max)) .. textRating
		end		
	end

	if SortField == "pp" then
		SortField = "name"
	else 
		SortField = "pp"
	end
	--запись рейтинга во фрейм скроллинга
	eb:SetText(textRating)	
end

--получаем числа для формулы рола из гильдейской информации
--правило записиси: на отдельной строке :0.5,0.25
--в итоге получаем массив с ключами: [1] = 0.5, [2] = 0.25
function GTD_GetDigitsF()
  local i = GetGuildInfoText()    
  if i then
    if i == "" then
      return {0, 0}
    else      
	  local _, _, _min, _max = string.find(i, "[:](%d+[.]%d+)[,]+(%d+[.]%d+)");
      if _min and _max then
        return {tonumber(_min), tonumber(_max)}
	  else 
		  return {0, 0}
      end
    end
  else 
	  return {0,0}
  end
end

function GTD_Split(inputstr, sep)  
  if sep == nil then
    sep = "%s"
  end
  local t={}
  local _string_find = string.gfind
  local _searchedSplit = _string_find(inputstr, "([^"..sep.."]+)") 
  for str in _searchedSplit do
    table.insert(t, str)
  end
  return t
end

local _allZones = {		
		"Onyxia's Lair",--1
		"Molten Core",--2
		"Emerald Sanctum",--3
		"Blackwing Lair",--4
		"Ahn'Qiraj",--5
		"Naxxramas",--6
		"Tel'Abim",--7 debug only		
	}

function GTD_SetZones()
  if table.getn(AccessInstances) > 0 then  	
  	return false	
	end

  local i = GetGuildInfoText()
  if i then
    if i == "" then
      return nil
    else    	
    	local _string_find = --[[string.gmatch or]] string.find
    	local _, _, _ids = _string_find(i, "[=]+(%d+[,]+.*)");
			if _ids == nil then
  			_, _, _ids = _string_find(i, "[=]+(%d+)");
  			if _ids == nil then
   				DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FFОтсутствует информация о доступных подземельях.|r")
   				return nil
  			end
			end
	  	local _asd = GTD_Split(_ids,",")
		  local _countArray = table.getn(_asd)
		  for x = 1, _countArray do	  	 	
		   	table.insert(AccessInstances, _allZones[tonumber(_asd[x])])	  	 	
	  	end  		  	
		end		
	end
end

--булевая проверка текущей локации из разрешенного массива локаций
function GTD_IsZone()
	local _accessInstances = AccessInstances		
	for x = 1, table.getn(_accessInstances) do		
		if _accessInstances[x] == GetRealZoneText() then
			return true
		end
	end
	return nil
end

--проверка правильности бросков игроков. 
--Если была какая-либо модификация\взлом программы клиента (напр. изменение формулы), 
--то появится сообщение в системном чате для админа.
local f = CreateFrame("frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:SetScript("OnEvent", function()
	if event == "CHAT_MSG_SYSTEM" then
		GTD_SetZones()

		if GTD_IsZone() then   

			local _digits  = GTD_GetDigitsF()
			local _message = arg1
			local _, _, _author, _rollResult, _rollMin, _rollMax = string.find(_message, "(.+) rolls (%d+) %((%d+)-(%d+)%)")

			if _rollMin ~= nil and _rollMax ~= nil then
				_rollMin = ToInteger(_rollMin)
				_rollMax = ToInteger(_rollMax)
			end

			if _author then
				local _searchRaider = 0	    
				for y = 1, GetNumGuildMembers(1) do
					local _name, _rank, _rankIndex, _level, _class, _zone, _note, _officernote, _online, _status = GetGuildRosterInfo(y);				
					local _pp = tonumber(_officernote)				
					if _level == 60 and _author == _name then
						local _getRaiderMin = 1
						local _getRaiderMax = 100
						if type(_pp) == "number" and _pp > 1 then
							_getRaiderMin = math.floor(_pp * _digits[1])
							_getRaiderMax = math.floor(_pp * _digits[2] + 100)
						end		
						if (_rollMax > 100 or (_rollMin > 1 and _rollMax <= 100)) 
							and (_getRaiderMin ~= _rollMin or _rollMax ~= _getRaiderMax) then							
							if ((_rollMin - 1) ~= _getRaiderMin or (_rollMax - 1) ~= _getRaiderMax) and _rollMax > _getRaiderMax then --если запаздывание больше на 1 очко чем можно, то минус один, наоборот - плюс один					
								local send_text = GTDA_GetTextAnnoAbuse(_rollMin, _rollMax, _name, _getRaiderMin, _getRaiderMax) 
								if GTDA_WISPER_ABUSE == 1 then
									SendChatMessage(send_text, "WHISPER", nil, UnitName("player"));
								end
								DEFAULT_CHAT_FRAME:AddMessage(send_text);
							end
						end	
					end		
				end			
			end	    
		end 
	end 
end)

function GTDA_GetTextAnnoAbuse(rollmin, rollmax, raider, getmin, getmax)
	return "|cFFff3939 Интервал рола: " .. rollmin .. "-" .. rollmax .. "|r |cFFff8686 не соотв. для игрока `".. raider .."`. Его доступный диапазон по PP:|r |cFFFFFFFF".. getmin .. "-" .. getmax .."|r"
end

local function GTD_GetItemLinkData(unitID, slotId)	
	local itemLink = nil
	if (unitID == nil) then
		itemLink = GetInventoryItemLink("player", slotId)
	else
		itemLink = GetInventoryItemLink(unitID, slotId)
	end

	if (itemLink) then
		local _, _, itemName = string.find(itemLink, "^.*%[(.*)%].*$")
		return itemName, itemLink
	end
end

--проверка плаща Ониксии на рейдерах
function GTD_OSC(wisp)
	local _backName = "Onyxia Scale Cloak";
  local _log = "|cFFFF8080Проверка рейда на плащ Ониксии...|r\r"
  
  for i = 1, GetNumRaidMembers() do
		local unit = 'raid' .. i;
		local who = UnitName(unit);		
		local itemName, itemLink, enchantId  = GTD_GetItemLinkData(unit, 15)		
		if itemName ~= _backName and itemLink then
			_log = _log  .. "|cFFFFFF00" .. who .. "|r" .. " одет: " .. tostring(itemLink) .. ", "
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(_log)

	if wisp ~= nil then
		SendChatMessage(_log, "WHISPER", nil, UnitName("player"));
	end
end

--функция авторола
function GTD_AutoRoll(id)
	local  inInstance, instanceType = IsInInstance()
	notInInstance   = (instanceType == 'none');
	inPartyInstance = (instanceType == 'party');
	inRaidInstance  = (instanceType == 'raid');
	inArenaInstance = (instanceType == 'arena');
	inPvPInstance   = (instanceType == 'pvp');
	isLeader = IsRaidLeader();
	class = UnitClass("Player");
	
	RollReturn = function()
		local txt = ""
		if isLeader then
			txt = "NEED"
		elseif not isLeader then
			txt = "PASS"
		end
		return txt
	end
	if inRaidInstance then	
		local _, name, _, quality = GetLootRollItemInfo(id);
		if string.find(name ,"Hakkari Bijou") or string.find(name ,"Coin") then
			RollOnLoot(id, 1);
			local _, _, _, hex = GetItemQualityColor(quality)
			DEFAULT_CHAT_FRAME:AddMessage("GTD: Auto NEED "..hex..GetLootRollItemLink(id))
			return
		end
	elseif GetRealZoneText() == "The Black Morass" then
		local _, name, _, quality = GetLootRollItemInfo(id);
		local nameItem = "Corrupted Sand"
		if string.find(name , nameItem) then
			RollOnLoot(id, 1);
			ConfirmBindOnUse();
			ConfirmLootRoll(id, 1);
			local _, _, _, hex = GetItemQualityColor(quality)
			DEFAULT_CHAT_FRAME:AddMessage("GTD: Auto NEED "..hex..GetLootRollItemLink(id))
			return
		end		
	end	
end

--авторолы в инстах
local gtdEvents = CreateFrame("frame")
gtdEvents:RegisterEvent("START_LOOT_ROLL")
gtdEvents:SetScript("OnEvent", function()
	if event == "START_LOOT_ROLL" then
		GTD_AutoRoll(arg1)
	end
end)

function Swin()	
	PickupInventoryItem(16);
	PickupInventoryItem(17);
end

--Боссы для progress-points
ListBosses = {}
ListBosses[_allZones[1]] = {--Ony
		"Onyxia",		
}
ListBosses[_allZones[2]] = {--Molten Core
		"Baron Geddon",
		"Garr",
		"Gehennas",
		"Golemagg the Incinerator",
		"Lucifron",
		"Magmadar",
		"Majordomo Executus",
		"Ragnaros",
		"Shazzrah",
		"Sulfuron Harbinger",
}
ListBosses[_allZones[3]] = {--Emerald Sanctum
		"Erennius",
		"Solnius the Awakener",
}
ListBosses[_allZones[4]] = {--BWL
		"Broodlord Lashlayer",
		"Chromaggus",
		"Ebonroc",
		"Firemaw",
		"Flamegor",
		"Nefarian",
		"Razorgore the Untamed",
		"Vaelastrasz the Corrupt",
}
ListBosses[_allZones[5]] = {--AQ40
		"Battleguard Sartura",
		"C'Thun",
		"Emperor Vek'lor",
		"Fankriss the Unyielding",
		"Lord Kri",
		"Ouro",
		"Princess Huhuran",
		"Viscidus",
		"The Prophet Skeram",
}
ListBosses[_allZones[5]] = {--Naxx
		"Anub'Rekhan",
		"Gluth",
		"Gothik the Harvester",
		"Grand Widow Faerlina",
		"Grobbulus",
		"Heigan the Unclean",
		"Highlord Mograine",
		"Instructor Razuvious",
		"Kel'Thuzad",
		"Loatheb",
		"Maexxna",
		"Noth the Plaguebringer",
		"Patchwerk",
		"Sapphiron",
		"Thaddius",
}
ListBosses[_allZones[7]] = {--debug Tel'Abim				
		"Spitefin Murloc",	
		"Spitefin Tidecaller",	
		"Spitefin Netter",	
}


local BossName = ""

--проверка на то, что босс является именно тем, кто нам нужен
--возврат булева значения
function GTD_CheckTarget()  
  if ListBosses[GetRealZoneText()] ~= nil and  table.getn(ListBosses[GetRealZoneText()]) > 0 then
	  for i = 1, GetNumRaidMembers() do
	    local _target = UnitName("Raid" .. i .. "target");
	    for _, bossName in ListBosses[GetRealZoneText()] do    	
		    if _target == bossName then    
		      BossName = _target
		      return true
		    end
	  	end
	  end
  end
  return nil
end

local Status = nil
--идентификация входа в бой, если таргет соотв критерию
local uic = CreateFrame("frame")
uic:RegisterEvent("UNIT_COMBAT")
uic:SetScript("OnEvent", function()		  	
  if event == "UNIT_COMBAT" and GTD_CheckTarget() and not Status then  	
  	--DEFAULT_CHAT_FRAME:AddMessage("Евент1: " .. event)
  	Status = "start"  	 	
  end 	
end)

--идентификация выхода из боя, при нужном таргете
local plc = CreateFrame("frame")
plc:RegisterEvent("PLAYER_REGEN_ENABLED")
plc:SetScript("OnEvent", function()
  if event == "PLAYER_REGEN_ENABLED" and Status == "start" then 
  	--DEFAULT_CHAT_FRAME:AddMessage("Евент2: " .. event)
  	Status = "leave"  	
  end
end)

--идентиф смены таргета после боя с нужным таргетом (БОСС)
local pre = CreateFrame("frame")
pre:RegisterEvent("PLAYER_TARGET_CHANGED")
pre:SetScript("OnEvent", function()		
  if event == "PLAYER_TARGET_CHANGED" and Status == "leave" then
  	--DEFAULT_CHAT_FRAME:AddMessage("Евент3: " .. event)
  	for i = 1, GetNumRaidMembers() do
	    local _isDeadTarget = UnitIsDeadOrGhost("Raid" .. i .. "target");
		  local _target = UnitName("Raid" .. i .. "target");
		  if _isDeadTarget == 1 and _target ~= nil  then
		    --DEFAULT_CHAT_FRAME:AddMessage("Ваша цель: " .. _target)
		    --DEFAULT_CHAT_FRAME:AddMessage("Статус цели: |cFF00FF00".. _isDeadTarget .."|r")	
		    --StaticPopup_Show("CONFIRM_ADD", EnteredValue:GetNumber());		      
		    _isDeadTarget = nil		
		    Status = nil    
		    return
  		end
  	end
  	--Status = nil   	
  end
end)

function GTDA_CheckValue(GlobalVariable)	
	if not GlobalVariable or GlobalVariable == StrOptionNo then		
		return nil 
	end	
	return true
end

function GTDA_GetTitleValue(GlobalVariable)
	if GlobalVariable == 1 then		
		return StrOptionYes
	else
		return StrOptionNo
	end
end

function GTDA_SetWisperPP()		
	local v = this:GetText()	
	if not GTDA_CheckValue(v) then		
		GTDA_WISPER_PP = 1		
	else		
		GTDA_WISPER_PP = 0		
	end
	this:SetText(GTDA_GetTitleValue(GTDA_WISPER_PP))
end

function GTDA_SetWisperAbuse()		
	local v = this:GetText()	
	if not GTDA_CheckValue(v) then		
		GTDA_WISPER_ABUSE = 1		
	else		
		GTDA_WISPER_ABUSE = 0		
	end
	this:SetText(GTDA_GetTitleValue(GTDA_WISPER_ABUSE))
end

function GTDA_StartSettings()
	MessageToWisperPP:SetText(GTDA_GetTitleValue(GTDA_WISPER_PP))
	MessageToWisperAbuse:SetText(GTDA_GetTitleValue(GTDA_WISPER_ABUSE))	
end

function GTDA_DebugOfWispers()
	if GTDA_WISPER_PP == 1 then
		local send_text1 = GTDA_GetTextAnnoAddedPP(2)
		SendChatMessage(send_text1, "WHISPER", nil, UnitName("player"))
	else 
		DEFAULT_CHAT_FRAME:AddMessage("Wips об начислении pp не включен!", 1,1,0)
	end

	if GTDA_WISPER_ABUSE == 1 then
		local send_text2 = GTDA_GetTextAnnoAbuse(134, 234, "NickNameRaider", 45, 145)
		SendChatMessage(send_text2, "WHISPER", nil, UnitName("player"));
	else 
		DEFAULT_CHAT_FRAME:AddMessage("Wips об уловках игроков не включен!", 1,1,0)
	end
end

