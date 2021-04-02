ESX = nil
local MafiaJobs = {}
local RegisteredSocieties = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function GetSociety(name)
	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			return RegisteredSocieties[i]
		end
	end
end

MySQL.ready(function()
	local result = MySQL.Sync.fetchAll('SELECT * FROM mafiajobs', {})

	for i=1, #result, 1 do
		MafiaJobs[result[i].name]        = result[i]
		MafiaJobs[result[i].name].mafiagrades = {}
	end

	local result2 = MySQL.Sync.fetchAll('SELECT * FROM mafiajob_grades', {})

	for i=1, #result2, 1 do
		MafiaJobs[result2[i].mafiajob_name].mafiagrades[tostring(result2[i].mafiagrade)] = result2[i]
	end
end)

AddEventHandler('esx_mafiasociety:registerSociety', function(name, label, account, datastore, inventory, data)
	local found = false

	local society = {
		name      = name,
		label     = label,
		account   = account,
		datastore = datastore,
		inventory = inventory,
		data      = data,
	}

	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			found = true
			RegisteredSocieties[i] = society
			break
		end
	end

	if not found then
		table.insert(RegisteredSocieties, society)
	end
end)

AddEventHandler('esx_mafiasociety:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_mafiasociety:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_mafiasociety:withdrawMoney')
AddEventHandler('esx_mafiasociety:withdrawMoney', function(society, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(society)
	local playerName = GetPlayerName(source)
    local playerHex = GetPlayerIdentifier(source)
    local group = xPlayer.getGroup()
	amount = ESX.Math.Round(tonumber(amount))

	if xPlayer.mafiajob.name ~= society.name then
		print(('esx_mafiasociety: %s attempted to call withdrawMoney!'):format(xPlayer.identifier))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if amount > 0 and account.money >= amount then
			account.removeMoney(amount)
			xPlayer.addMoney(amount)

			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('have_withdrawn', ESX.Math.GroupDigits(amount)))
		else
			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('invalid_amount'))
		end
	end)
end)

RegisterServerEvent('esx_mafiasociety:depositMoney')
AddEventHandler('esx_mafiasociety:depositMoney', function(society, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(society)
	local playerName = GetPlayerName(source)
    local playerHex = GetPlayerIdentifier(source)
    local group = xPlayer.getGroup()
	amount = ESX.Math.Round(tonumber(amount))

	if xPlayer.mafiajob.name ~= society.name then
		print(('esx_mafiasociety: %s attempted to call depositMoney!'):format(xPlayer.identifier))
		return
	end

	if amount > 0 and xPlayer.getMoney() >= amount then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			xPlayer.removeMoney(amount)
			account.addMoney(amount)
		end)

		TriggerClientEvent('esx:showNotification', xPlayer.source, _U('have_deposited', ESX.Math.GroupDigits(amount)))
	else
		TriggerClientEvent('esx:showNotification', xPlayer.source, _U('invalid_amount'))
	end
end)

RegisterServerEvent('esx_mafiasociety:washMoney')
AddEventHandler('esx_mafiasociety:washMoney', function(society, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local account = xPlayer.getAccount('black_money')
	amount = ESX.Math.Round(tonumber(amount))

	if xPlayer.mafiajob.name ~= society then
		print(('esx_mafiasociety: %s attempted to call washMoney!'):format(xPlayer.identifier))
		return
	end

	if amount and amount > 0 and account.money >= amount then
		xPlayer.removeAccountMoney('black_money', amount)

		MySQL.Async.execute('INSERT INTO society_moneywash (identifier, society, amount) VALUES (@identifier, @society, @amount)', {
			['@identifier'] = xPlayer.identifier,
			['@society']    = society,
			['@amount']     = amount
		}, function(rowsChanged)
			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('you_have', ESX.Math.GroupDigits(amount)))
		end)
	else
		TriggerClientEvent('esx:showNotification', xPlayer.source, _U('invalid_amount'))
	end

end)

RegisterServerEvent('esx_mafiasociety:putVehicleInGarage')
AddEventHandler('esx_mafiasociety:putVehicleInGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_mafiasociety:removeVehicleFromGarage')
AddEventHandler('esx_mafiasociety:removeVehicleFromGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if garage[i].plate == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

ESX.RegisterServerCallback('esx_mafiasociety:getSocietyMoney', function(source, cb, societyName)
	local society = GetSociety(societyName)

	if society then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			cb(account.money)
		end)
	else
		cb(0)
	end
end)

ESX.RegisterServerCallback('esx_mafiasociety:getEmployees', function(source, cb, society)
	if Config.EnableESXIdentity then

		MySQL.Async.fetchAll('SELECT firstname, lastname, identifier, mafiajob, mafiajob_grade FROM users WHERE mafiajob = @mafiajob ORDER BY mafiajob_grade DESC', {
			['@mafiajob'] = society
		}, function (results)
			local employees = {}

			for i=1, #results, 1 do
				table.insert(employees, {
					name       = results[i].firstname .. ' ' .. results[i].lastname,
					identifier = results[i].identifier,
					mafiajob = {
						name        = results[i].mafiajob,
						label       = MafiaJobs[results[i].mafiajob].label,
						mafiagrade       = results[i].mafiajob_grade,
						grade_name  = MafiaJobs[results[i].mafiajob].mafiagrades[tostring(results[i].mafiajob_grade)].name,
						grade_label = MafiaJobs[results[i].mafiajob].mafiagrades[tostring(results[i].mafiajob_grade)].label
					}
				})
			end

			cb(employees)
		end)
	else
		MySQL.Async.fetchAll('SELECT name, identifier, mafiajob, mafiajob_grade FROM users WHERE mafiajob = @mafiajob ORDER BY mafiajob_grade DESC', {
			['@mafiajob'] = society
		}, function (result)
			local employees = {}

			for i=1, #result, 1 do
				table.insert(employees, {
					name       = result[i].name,
					identifier = result[i].identifier,
					mafiajob = {
						name        = result[i].mafiajob,
						label       = MafiaJobs[result[i].mafiajob].label,
						mafiagrade       = result[i].mafiajob_grade,
						grade_name  = MafiaJobs[result[i].mafiajob].mafiagrades[tostring(result[i].mafiajob_grade)].name,
						grade_label = MafiaJobs[result[i].mafiajob].mafiagrades[tostring(result[i].mafiajob_grade)].label
					}
				})
			end

			cb(employees)
		end)
	end
end)

ESX.RegisterServerCallback('esx_mafiasociety:getJob', function(source, cb, society)
	local mafiajob    = json.decode(json.encode(MafiaJobs[society]))
	local mafiagrades = {}

	for k,v in pairs(mafiajob.mafiagrades) do
		table.insert(mafiagrades, v)
	end

	table.sort(mafiagrades, function(a, b)
		return a.mafiagrade < b.mafiagrade
	end)

	mafiajob.mafiagrades = mafiagrades

	cb(mafiajob)
end)


ESX.RegisterServerCallback('esx_mafiasociety:setJob', function(source, cb, identifier, mafiajob, mafiagrade, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.mafiajob.grade_name == 'boss'

	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)

		if xTarget then
			xTarget.setMafiaJob(mafiajob, mafiagrade)

			if type == 'hire' then
				TriggerClientEvent('esx:showNotification', xTarget.source, _U('you_have_been_hired', mafiajob))
				MySQL.Async.execute('UPDATE users SET mafiajob = @mafiajob, mafiajob_grade = @mafiajob_grade WHERE identifier = @identifier', {
					['@mafiajob']        = mafiajob,
					['@mafiajob_grade']  = mafiagrade,
					['@identifier'] = identifier
				}, function(rowsChanged)
					cb()
				end)
			elseif type == 'promote' then
				TriggerClientEvent('esx:showNotification', xTarget.source, _U('you_have_been_promoted'))
				MySQL.Async.execute('UPDATE users SET mafiajob = @mafiajob, mafiajob_grade = @mafiajob_grade WHERE identifier = @identifier', {
					['@mafiajob']        = mafiajob,
					['@mafiajob_grade']  = mafiagrade,
					['@identifier'] = identifier
				}, function(rowsChanged)
					cb()
				end)
			elseif type == 'fire' then
				TriggerClientEvent('esx:showNotification', xTarget.source, _U('you_have_been_fired', xTarget.getJob().label))
				MySQL.Async.execute('UPDATE users SET mafiajob = @mafiajob, mafiajob_grade = @mafiajob_grade WHERE identifier = @identifier', {
					['@mafiajob']        = mafiajob,
					['@mafiajob_grade']  = mafiagrade,
					['@identifier'] = identifier
				}, function(rowsChanged)
					cb()
				end)
			end

			cb()
		else
			MySQL.Async.execute('UPDATE users SET mafiajob = @mafiajob, mafiajob_grade = @mafiajob_grade WHERE identifier = @identifier', {
				['@mafiajob']        = mafiajob,
				['@mafiajob_grade']  = mafiagrade,
				['@identifier'] = identifier
			}, function(rowsChanged)
				cb()
			end)
		end
	else
		print(('esx_mafiasociety: %s attempted to set mafiaJob'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_mafiasociety:setJobSalary', function(source, cb, mafiajob, mafiagrade, salary)
	local isBoss = isPlayerBoss(source, mafiajob)
	local identifier = GetPlayerIdentifier(source, 0)

	if isBoss then
		if salary <= Config.MaxSalary then
			MySQL.Async.execute('UPDATE mafiajob_grades SET salary = @salary WHERE mafiajob_name = @mafiajob_name AND mafiagrade = @mafiagrade', {
				['@salary']   = salary,
				['@mafiajob_name'] = mafiajob,
				['@mafiagrade']    = mafiagrade
			}, function(rowsChanged)
				MafiaJobs[mafiajob].mafiagrades[tostring(mafiagrade)].salary = salary
				local xPlayers = ESX.GetPlayers()

				for i=1, #xPlayers, 1 do
					local xPlayer = ESX.GetPlayerFromId(xPlayers[i])

					if xPlayer.mafiajob.name == mafiajob and xPlayer.mafiajob.mafiagrade == mafiagrade then
						xPlayer.setMafiaJob(mafiajob, mafiagrade)
					end
				end

				cb()
			end)
		else
			print(('esx_mafiasociety: %s attempted to set mafiaJobSalary over config limit!'):format(identifier))
			cb()
		end
	else
		print(('esx_mafiasociety: %s attempted to set mafiaJobSalary'):format(identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_mafiasociety:getOnlinePlayers', function(source, cb)
	local xPlayers = ESX.GetPlayers()
	local players  = {}

	for i=1, #xPlayers, 1 do
		local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
		table.insert(players, {
			source     = xPlayer.source,
			identifier = xPlayer.identifier,
			name       = xPlayer.name,
			mafiajob        = xPlayer.mafiajob
		})
	end

	cb(players)
end)

ESX.RegisterServerCallback('esx_mafiasociety:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

ESX.RegisterServerCallback('esx_mafiasociety:isBoss', function(source, cb, mafiajob)
	cb(isPlayerBoss(source, mafiajob))
end)

function isPlayerBoss(playerId, mafiajob)
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer.mafiajob.name == mafiajob and xPlayer.mafiajob.grade_name == 'boss' then
		return true
	else
		TriggerClientEvent('esx:showNotification', xPlayer.source, '~r~Error: ~w~You are not the boss of this ~u~mafia~w~!')
		print(('esx_mafiasociety: %s attempted open a society boss menu!'):format(xPlayer.identifier))
		return false
	end
end
