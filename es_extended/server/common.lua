ESX                      = {}
ESX.Players              = {}
ESX.UsableItemsCallbacks = {}
ESX.Items                = {}
ESX.ServerCallbacks      = {}
ESX.TimeoutCount         = -1
ESX.CancelledTimeouts    = {}
ESX.LastPlayerData       = {}
ESX.Pickups              = {}
ESX.PickupId             = 0
ESX.Jobs                 = {}
ESX.MafiaJobs                 = {}

AddEventHandler('esx:getSharedObject', function(cb)
	cb(ESX)
end)

function getSharedObject()
	return ESX
end

MySQL.ready(function()
	MySQL.Async.fetchAll('SELECT * FROM items', {}, function(result)
		for i=1, #result, 1 do
			ESX.Items[result[i].name] = {
				label     = result[i].label,
				limit     = result[i].limit,
				rare      = (result[i].rare       == 1 and true or false),
				canRemove = (result[i].can_remove == 1 and true or false),
			}
		end
	end)

	local result = MySQL.Sync.fetchAll('SELECT * FROM jobs', {})

	for i=1, #result do
		ESX.Jobs[result[i].name] = result[i]
		ESX.Jobs[result[i].name].grades = {}
	end

	local result2 = MySQL.Sync.fetchAll('SELECT * FROM job_grades', {})

	for i=1, #result2 do
		if ESX.Jobs[result2[i].job_name] then
			ESX.Jobs[result2[i].job_name].grades[tostring(result2[i].grade)] = result2[i]
		else
			print(('es_extended: invalid job "%s" from table job_grades ignored!'):format(result2[i].job_name))
		end
	end

	for k,v in pairs(ESX.Jobs) do
		if next(v.grades) == nil then
			ESX.Jobs[v.name] = nil
			print(('es_extended: ignoring job "%s" due to missing job grades!'):format(v.name))
		end
	end

	-- mafia

	local mafiaresult = MySQL.Sync.fetchAll('SELECT * FROM mafiajobs', {})

	for i=1, #mafiaresult do
		ESX.MafiaJobs[mafiaresult[i].name] = mafiaresult[i]
		ESX.MafiaJobs[mafiaresult[i].name].mafiagrades = {}
	end

	local mafiaresult2 = MySQL.Sync.fetchAll('SELECT * FROM mafiajob_grades', {})

	for i=1, #mafiaresult2 do
		if ESX.MafiaJobs[mafiaresult2[i].mafiajob_name] then
			ESX.MafiaJobs[mafiaresult2[i].mafiajob_name].mafiagrades[tostring(mafiaresult2[i].mafiagrade)] = mafiaresult2[i]
		else
			print(('es_extended: invalid mafia job "%s" from table mafiajob_grades ignored!'):format(mafiaresult2[i].mafiajob_name))
		end
	end

	for l,b in pairs(ESX.MafiaJobs) do
		if next(b.mafiagrades) == nil then
			ESX.MafiaJobs[b.name] = nil
			print(('es_extended: ignoring mafia job "%s" due to missing mafiajob grades!'):format(b.name))
		end
	end
end)

AddEventHandler('esx:playerLoaded', function(source)
	local xPlayer         = ESX.GetPlayerFromId(source)
	local accounts        = {}
	local items           = {}
	local xPlayerAccounts = xPlayer.getAccounts()
	local xPlayerItems    = xPlayer.getInventory()

	for i=1, #xPlayerAccounts, 1 do
		accounts[xPlayerAccounts[i].name] = xPlayerAccounts[i].money
	end

	for i=1, #xPlayerItems, 1 do
		items[xPlayerItems[i].name] = xPlayerItems[i].count
	end

	ESX.LastPlayerData[source] = {
		accounts = accounts,
		items    = items
	}
end)

RegisterServerEvent('esx:clientLog')
AddEventHandler('esx:clientLog', function(msg)
	RconPrint(msg .. "\n")
end)

RegisterServerEvent('esx:triggerServerCallback')
AddEventHandler('esx:triggerServerCallback', function(name, requestId, ...)
	local _source = source

	ESX.TriggerServerCallback(name, requestID, _source, function(...)
		TriggerClientEvent('esx:serverCallback', _source, requestId, ...)
	end, ...)
end)
