// SPDX-License-Identifier: GPL-3.0-only
#import "MHTLocalization.h"
#import "MHTMenu.h"
static NSMenu *submenu(NSMenu *parent,NSString *title) {
    NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:title action:NULL keyEquivalent:@""];
    NSMenu *menu=[[NSMenu alloc]initWithTitle:title];item.submenu=menu;[parent addItem:item];return menu;
}
void MHTInstallMenus(MHTApp *target) {
    NSMenu *bar=[NSMenu new],*app=submenu(bar,@"TrainerDock");
    [app addItemWithTitle:MHTLocalized(@"Über TrainerDock") action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings=[app addItemWithTitle:MHTLocalized(@"Einstellungen …") action:@selector(openSettings:) keyEquivalent:@","];settings.target=target;
    NSMenuItem *updates=[app addItemWithTitle:MHTLocalized(@"Nach Updates suchen …") action:@selector(checkForUpdates:) keyEquivalent:@""];updates.target=target;
    NSMenuItem *automatic=[app addItemWithTitle:MHTLocalized(@"Automatisch nach Updates suchen") action:@selector(toggleAutomaticChecks:) keyEquivalent:@""];automatic.target=target;
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:MHTLocalized(@"TrainerDock ausblenden") action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hide=[app addItemWithTitle:MHTLocalized(@"Andere ausblenden") action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hide.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagOption;
    [app addItemWithTitle:MHTLocalized(@"Alle einblenden") action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:MHTLocalized(@"TrainerDock beenden") action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenu *edit=submenu(bar,MHTLocalized(@"Bearbeiten"));
    [edit addItemWithTitle:MHTLocalized(@"Widerrufen") action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"];
    NSMenuItem *redo=[edit addItemWithTitle:MHTLocalized(@"Wiederholen") action:NSSelectorFromString(@"redo:") keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagShift;
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:MHTLocalized(@"Ausschneiden") action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:MHTLocalized(@"Kopieren") action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:MHTLocalized(@"Einfügen") action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:MHTLocalized(@"Alles auswählen") action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenu *trainers=submenu(bar,MHTLocalized(@"Trainer"));
    NSMenuItem *library=[trainers addItemWithTitle:MHTLocalized(@"Bibliothek anzeigen") action:@selector(showLibrary:) keyEquivalent:@"1"];library.target=target;
    NSMenuItem *manage=[trainers addItemWithTitle:MHTLocalized(@"Trainer & Spielpfade …") action:@selector(openSettings:) keyEquivalent:@""];manage.target=target;
    NSMenuItem *downloads=[trainers addItemWithTitle:MHTLocalized(@"Trainer laden & verwalten …") action:@selector(openTrainerLibrary:) keyEquivalent:@"2"];downloads.target=target;
    NSMenuItem *trainerUpdates=[trainers addItemWithTitle:MHTLocalized(@"Nach Trainerupdates suchen") action:@selector(checkTrainerUpdates:) keyEquivalent:@""];trainerUpdates.target=target;
    [trainers addItem:NSMenuItem.separatorItem];
    NSMenuItem *refresh=[trainers addItemWithTitle:MHTLocalized(@"Trainer & Spiele neu laden") action:@selector(rescan:) keyEquivalent:@"r"];refresh.target=target;
    NSMenu *windows=submenu(bar,MHTLocalized(@"Fenster"));
    [windows addItemWithTitle:MHTLocalized(@"Schließen") action:@selector(performClose:) keyEquivalent:@"w"];
    [windows addItemWithTitle:MHTLocalized(@"Im Dock ablegen") action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windows addItemWithTitle:MHTLocalized(@"Zoomen") action:@selector(performZoom:) keyEquivalent:@""];
    [windows addItem:NSMenuItem.separatorItem];
    [windows addItemWithTitle:MHTLocalized(@"Alle nach vorne bringen") action:@selector(arrangeInFront:) keyEquivalent:@""];
    NSApp.mainMenu=bar;NSApp.windowsMenu=windows;
}
