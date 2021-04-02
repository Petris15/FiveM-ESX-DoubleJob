ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().mafiajob == nil do
		Citizen.Wait(10)
	end

	ESX.PlayerData = ESX.GetPlayerData()

	RefreshMafiaBussHUD()
end)

RegisterNetEvent('esx:setMafiaJob')
AddEventHandler('esx:setMafiaJob', function(mafiajob)
	ESX.PlayerData.mafiajob = mafiajob
	RefreshMafiaBussHUD()
end)

function RefreshMafiaBussHUD()
	DisableSocietyMoneyHUDElement()

	if ESX.PlayerData.mafiajob.grade_name == 'boss' then
		EnableSocietyMoneyHUDElement()

		ESX.TriggerServerCallback('esx_mafiasociety:getSocietyMoney', function(money)
			UpdateSocietyMoneyHUDElement(money)
		end, ESX.PlayerData.mafiajob.name)
	end
end

RegisterNetEvent('esx_addonaccount:setMoney')
AddEventHandler('esx_addonaccount:setMoney', function(society, money)
	if ESX.PlayerData.mafiajob and ESX.PlayerData.mafiajob.grade_name == 'boss' and 'society_' .. ESX.PlayerData.mafiajob.name == society then
		UpdateSocietyMoneyHUDElement(money)
	end
end)

function EnableSocietyMoneyHUDElement()

	TriggerEvent('esx_mafiasociety:toggleSocietyHud', true)
end

function DisableSocietyMoneyHUDElement()

	TriggerEvent('esx_mafiasociety:toggleSocietyHud', false)
end

function UpdateSocietyMoneyHUDElement(money)

	TriggerEvent('esx_mafiasociety:setSocietyMoney', money)
end

function OpenBossMenu(society, close, options)
	local isBoss = nil
	local options  = options or {}
	local elements = {}

	ESX.TriggerServerCallback('esx_mafiasociety:isBoss', function(result)
		isBoss = result
	end, society)

	while isBoss == nil do
		Citizen.Wait(100)
	end

	if not isBoss then
		return
	end

	local defaultOptions = {
		withdraw  = true,
		deposit   = true,
		employees = true
	}

	for k,v in pairs(defaultOptions) do
		if options[k] == nil then
			options[k] = v
		end
	end

	if options.withdraw then
		table.insert(elements, {label = _U('withdraw_society_money'), value = 'withdraw_society_money'})
	end

	if options.deposit then
		table.insert(elements, {label = _U('deposit_society_money'), value = 'deposit_money'})
	end

	if options.employees then
		table.insert(elements, {label = _U('employee_management'), value = 'manage_employees'})
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'boss_actions_' .. society, {
		title    = _U('boss_menu'),
		align    = 'top-left',
		elements = elements
	}, function(data, menu)

		if data.current.value == 'withdraw_society_money' then

			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'withdraw_society_money_amount_' .. society, {
				title = _U('withdraw_amount')
			}, function(data, menu)

				local amount = tonumber(data.value)

				if amount == nil then
					ESX.ShowNotification(_U('invalid_amount'))
				else
					menu.close()
					TriggerServerEvent('esx_mafiasociety:withdrawMoney', society, amount)
				end

			end, function(data, menu)
				menu.close()
			end)

		elseif data.current.value == 'deposit_money' then

			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'deposit_money_amount_' .. society, {
				title = _U('deposit_amount')
			}, function(data, menu)

				local amount = tonumber(data.value)

				if amount == nil then
					ESX.ShowNotification(_U('invalid_amount'))
				else
					menu.close()
					TriggerServerEvent('esx_mafiasociety:depositMoney', society, amount)
				end

			end, function(data, menu)
				menu.close()
			end)

		elseif data.current.value == 'manage_employees' then
			OpenManageEmployeesMenu(society)
		end

	end, function(data, menu)
		if close then
			close(data, menu)
		end
	end)

end

function OpenManageEmployeesMenu(society)

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'manage_employees_' .. society, {
		title    = _U('employee_management'),
		align    = 'top-left',
		elements = {
			{label = _U('employee_list'), value = 'employee_list'},
			{label = _U('recruit'),       value = 'recruit'}
		}
	}, function(data, menu)

		if data.current.value == 'employee_list' then
			OpenEmployeeList(society)
		end

		if data.current.value == 'recruit' then
			OpenRecruitMenu(society)
		end

	end, function(data, menu)
		menu.close()
	end)
end

function OpenEmployeeList(society)

	ESX.TriggerServerCallback('esx_mafiasociety:getEmployees', function(employees)

		local elements = {
			head = {_U('employee'), _U('grade'), _U('actions')},
			rows = {}
		}

		for i=1, #employees, 1 do
			local gradeLabel = (employees[i].mafiajob.grade_label == '' and employees[i].mafiajob.label or employees[i].mafiajob.grade_label)

			table.insert(elements.rows, {
				data = employees[i],
				cols = {
					employees[i].name,
					gradeLabel,
					'{{' .. _U('promote') .. '|promote}} {{' .. _U('fire') .. '|fire}}'
				}
			})
		end

		ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'employee_list_' .. society, elements, function(data, menu)
			local employee = data.data

			if data.value == 'promote' then
				menu.close()
				OpenPromoteMenu(society, employee)
			elseif data.value == 'fire' then
				ESX.ShowNotification(_U('you_have_fired', employee.name))

				ESX.TriggerServerCallback('esx_mafiasociety:setJob', function()
					OpenEmployeeList(society)
				end, employee.identifier, 'nomafia', 0, 'fire')
			end
		end, function(data, menu)
			menu.close()
			OpenManageEmployeesMenu(society)
		end)

	end, society)

end

function OpenRecruitMenu(society)

	ESX.TriggerServerCallback('esx_mafiasociety:getOnlinePlayers', function(players)

		local elements = {}

		for i=1, #players, 1 do
			if players[i].mafiajob.name ~= society then
				table.insert(elements, {
					label = players[i].name,
					value = players[i].source,
					name = players[i].name,
					identifier = players[i].identifier
				})
			end
		end

		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'recruit_' .. society, {
			title    = _U('recruiting'),
			align    = 'top-left',
			elements = elements
		}, function(data, menu)

			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'recruit_confirm_' .. society, {
				title    = _U('do_you_want_to_recruit', data.current.name),
				align    = 'top-left',
				elements = {
					{label = _U('no'),  value = 'no'},
					{label = _U('yes'), value = 'yes'}
				}
			}, function(data2, menu2)
				menu2.close()

				if data2.current.value == 'yes' then
					ESX.ShowNotification(_U('you_have_hired', data.current.name))

					ESX.TriggerServerCallback('esx_mafiasociety:setJob', function()
						OpenRecruitMenu(society)
					end, data.current.identifier, society, 0, 'hire')
				end
			end, function(data2, menu2)
				menu2.close()
			end)

		end, function(data, menu)
			menu.close()
		end)

	end)

end

function OpenPromoteMenu(society, employee)

	ESX.TriggerServerCallback('esx_mafiasociety:getJob', function(mafiajob)

		local elements = {}

		for i=1, #mafiajob.mafiagrades, 1 do
			local gradeLabel = (mafiajob.mafiagrades[i].label == '' and mafiajob.label or mafiajob.mafiagrades[i].label)

			table.insert(elements, {
				label = gradeLabel,
				value = mafiajob.mafiagrades[i].mafiagrade,
				selected = (employee.mafiajob.mafiagrade == mafiajob.mafiagrades[i].mafiagrade)
			})
		end

		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'promote_employee_' .. society, {
			title    = _U('promote_employee', employee.name),
			align    = 'top-left',
			elements = elements
		}, function(data, menu)
			menu.close()
			ESX.ShowNotification(_U('you_have_promoted', employee.name, data.current.label))

			ESX.TriggerServerCallback('esx_mafiasociety:setJob', function()
				OpenEmployeeList(society)
			end, employee.identifier, society, data.current.value, 'promote')
		end, function(data, menu)
			menu.close()
			OpenEmployeeList(society)
		end)

	end, society)

end

AddEventHandler('esx_mafiasociety:openBossMenu', function(society, close, options)
	OpenBossMenu(society, close, options)
end)
