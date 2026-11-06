// SPDX-License-Identifier: GPL-3.0-only
#import "MHTMenu.h"
static NSMenu *submenu(NSMenu *parent,NSString *title) {
    NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:title action:NULL keyEquivalent:@""];
    NSMenu *menu=[[NSMenu alloc]initWithTitle:title];item.submenu=menu;[parent addItem:item];return menu;
}
void MHTInstallMenus(MHTApp *target) {
    NSMenu *bar=[NSMenu new],*app=submenu(bar,@"TrainerDock");
    [app addItemWithTitle:@"Über TrainerDock" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings=[app addItemWithTitle:@"Einstellungen …" action:@selector(openSettings:) keyEquivalent:@","];settings.target=target;
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:@"TrainerDock ausblenden" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hide=[app addItemWithTitle:@"Andere ausblenden" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hide.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagOption;
    [app addItemWithTitle:@"Alle einblenden" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:@"TrainerDock beenden" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenu *edit=submenu(bar,@"Bearbeiten");
    [edit addItemWithTitle:@"Widerrufen" action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"];
    NSMenuItem *redo=[edit addItemWithTitle:@"Wiederholen" action:NSSelectorFromString(@"redo:") keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagShift;
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:@"Ausschneiden" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Kopieren" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Einfügen" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Alles auswählen" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenu *trainers=submenu(bar,@"Trainer");
    NSMenuItem *library=[trainers addItemWithTitle:@"Bibliothek anzeigen" action:@selector(showLibrary:) keyEquivalent:@"1"];library.target=target;
    NSMenuItem *manage=[trainers addItemWithTitle:@"Trainer & Spielpfade …" action:@selector(openSettings:) keyEquivalent:@""];manage.target=target;
    [trainers addItem:NSMenuItem.separatorItem];
    NSMenuItem *refresh=[trainers addItemWithTitle:@"Trainer & Spiele neu laden" action:@selector(rescan:) keyEquivalent:@"r"];refresh.target=target;
    NSMenu *windows=submenu(bar,@"Fenster");
    [windows addItemWithTitle:@"Schließen" action:@selector(performClose:) keyEquivalent:@"w"];
    [windows addItemWithTitle:@"Im Dock ablegen" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windows addItemWithTitle:@"Zoomen" action:@selector(performZoom:) keyEquivalent:@""];
    [windows addItem:NSMenuItem.separatorItem];
    [windows addItemWithTitle:@"Alle nach vorne bringen" action:@selector(arrangeInFront:) keyEquivalent:@""];
    NSApp.mainMenu=bar;NSApp.windowsMenu=windows;
}
