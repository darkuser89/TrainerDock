// SPDX-License-Identifier: GPL-3.0-only
#pragma once
// Exact Mac build 4C4C44ED-5555-3144-A15E-9285028AFD15. These are TDB indices, not absolute addresses.
enum { RE2Type_HP = 26336 };
enum { RE2Method_HP_get_CurrentHitPoint = 51240 };
enum { RE2Method_HP_set_CurrentHitPoint = 51241 };
enum { RE2Method_HP_get_DefaultHitPoint = 51238 };
enum { RE2Method_HP_get_Invincible = 51245 };
enum { RE2Method_HP_set_Invincible = 51246 };
enum { RE2Type_Condition = 38329 };
enum { RE2Method_Condition_get_HitPointController = 67683 };
enum { RE2Method_Condition_get_Equipment = 67613 };
enum { RE2Method_Condition_get_Controller = 67603 };
enum { RE2Method_Condition_get_Inventory = 67611 };
enum { RE2Type_Player = 20583 };
enum { RE2Method_Player_get_CurrentPlayerCondition = 422746 };
enum { RE2Method_Player_get_CurrentPlayer = 422748 };
enum { RE2Type_Equipment = 42564 };
enum { RE2Method_Equipment_get_MainWeapon = 59170 };
enum { RE2Method_Equipment_get_RecoilParam = 59183 };
enum { RE2Type_Gun = 18647 };
enum { RE2Method_Gun_get_FireBulletParam = 202535 };
enum { RE2Method_Gun_get_RecoilParam = 202537 };
enum { RE2Method_Gun_get_WpBulletCounter = 202549 };
enum { RE2Type_Bullet = 13364 };
enum { RE2Method_Bullet_get_Infinity = 242625 };
enum { RE2Method_Bullet_set_Infinity = 242626 };
enum { RE2Method_Bullet_get_Number = 242627 };
enum { RE2Method_Bullet_set_Number = 242628 };
enum { RE2Type_Component = 31491 };
enum { RE2Method_Component_get_GameObject = 5729 };
enum { RE2Method_Component_get_Valid = 5730 };
enum { RE2Type_WeakGO = 2519 };
enum { RE2Method_WeakGO__ctor = 9732 };
enum { RE2Method_WeakGO_get_Target = 9734 };
enum { RE2Type_Inventory = 24652 };
enum { RE2Method_Inventory_get_TypeWriterRemainCount = 141938 };
enum { RE2Method_Inventory_set_TypeWriterRemainCount = 141939 };
enum { RE2Method_Inventory_get_InventoryItemSlotCurrentSize = 141922 };
enum { RE2Method_Inventory_set_InventoryItemSlotCurrentSize = 141923 };
enum { RE2Method_Inventory_get_InventoryItemSlotMaxSize = 141924 };
enum { RE2Type_Record = 8432 };
enum { RE2Method_Record_get_GameClockRecordTime = 92913 };
enum { RE2Method_Record_get_PlayTime = 92918 };
enum { RE2Method_Record_get_CurrentSaveCount = 92933 };
enum { RE2Method_Record_set_CurrentSaveCount = 92934 };
enum { RE2Method_Record_get_OpenItemBox = 92954 };
enum { RE2Method_Record_get_UseHealItem = 92955 };
enum { RE2Method_Record_get_NumberOfSteps = 92956 };
enum { RE2Method_Record_set_NumberOfSteps = 92957 };
enum { RE2Type_Scene = 18897 };
enum { RE2Method_Scene_get_CurrentScene = 351449 };
enum { RE2Method_Scene_get_Loading = 351452 };
enum { RE2Type_CountDown = 390 };
enum { RE2Method_CountDown_get_CurrentTimerFrame = 223040 };
enum { RE2Method_CountDown_set_CurrentTimerFrame = 223041 };
enum { RE2Type_Enemy = 10375 };
enum { RE2Method_Enemy_get_EnemyList = 131235 };
// Exact TDB74 List<RegisterEnemyInfo>.get_Item (72634) returns 37733;
// RegisterEnemyInfo.get_Controller has no parameters and returns 12402.
enum { RE2Type_EnemyRegistration = 37733, RE2Type_EnemyArray = 42221 };
enum { RE2Method_EnemyRegistration_get_Controller = 72532 };
// Exact TDB74: MainFlowManager owns the campaign header SaveTimes.
// get_Instance returns MainFlowManager; SaveTimes getter has no arguments,
// setter accepts System.Int32.
enum { RE2Type_MainFlow = 33353, RE2Type_MainFlowSingleton = 16894 };
enum { RE2Method_MainFlow_get_Instance = 87579 };
enum { RE2Method_MainFlow_get_SaveTimes = 118067, RE2Method_MainFlow_set_SaveTimes = 118068 };
