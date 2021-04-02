## Description

[![][product-screenshot]](https://i.imgur.com/ZLcXlqu.png)

This script has been created especially for FiveM Roleplay servers. It allows you to have 2 jobs. That helps you make players have their legal and their illegal job at the same time. (The ESX version used is 1.1)

## Installation

1. Download this
2. Extract the ZIP file
3. Replace your previous `es_extended` with this one
4. Drag & Drop `esx_mafiasociety`
5. Import the `mafiajobs.sql` (You must have already the normal 1.1 sql data installed. This just adds what is important to make 2nd job working)
6. Start the `esx_mafiasociety` after es_extended but before your job scripts.

## Tutorial

To make a normal job gets only inserted in player's 2nd slot job you do all the following replaces:

-- SCRIPT REPLACES --
`esx_society` --> `esx_mafiasociety`
`ESX.GetPlayerData().job` --> `ESX.GetPlayerData().mafiajob`
`PlayerData.job` --> `PlayerData.mafiajob`
`xPlayer.job` --> `xPlayer.mafiajob`
`esx:setJob` ---> `esx:setMafiaJob`

-- SQL FILE REPLACES --
INSERT INTO `jobs` --> INSERT INTO `mafiajobs`
INSERT INTO `job_grades` --> INSERT INTO `mafiajob_grades`
`grade` --> `mafiagrade`

[product-screenshot]: https://i.imgur.com/ZLcXlqu.png
