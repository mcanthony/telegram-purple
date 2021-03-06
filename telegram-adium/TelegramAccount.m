/**
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111-1301  USA
 *
 * Copyright Matthias Jentsch 2014-2015
 */

#import "TelegramAccount.h"
#import "tgp-ft.h"

#import <libpurple/conversation.h>
#import <Adium/ESFileTransfer.h>
#import <Adium/AIListContact.h>
#import <Adium/AIToolbarControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIChat.h>

#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>

#include "telegram-purple.h"

@implementation TelegramAccount

- (const char*)protocolPlugin
{
	return "prpl-telegram";
}

- (NSString *)host
{
	return @"149.154.167.50";
}

- (BOOL)shouldDisplayOutgoingMUCMessages
{
  return NO;
}

- (int)port
{
	return 443;
}

- (void)didConnect
{
  [super didConnect];
  [self purpleAccount];
  purple_signal_connect (purple_conversations_get_handle(), "chat-buddy-joined",
                         [self purpleAccount], PURPLE_CALLBACK(chat_buddy_joined), (__bridge void *)(self));
  
  // Storing chats in the blist breaks Adium bookmarks. Adium doesn't
  // show those chats anyway, so we can just safely delete those.
  PurpleBlistNode *node = purple_blist_get_root();
  while (node) {
    if (PURPLE_BLIST_NODE_IS_CHAT(node)) {
      PurpleChat *ch = PURPLE_CHAT(node);
      if (purple_chat_get_account(ch) == account) {
        NSLog (@"Removing chat from blist: %s", ch->alias);
        purple_blist_remove_chat (ch);
      }
    }
    node = purple_blist_node_next (node, 0);
  }
}

- (void)didDisconnect
{
  purple_signal_disconnect(purple_conversations_get_handle(), "chat-buddy-joined",
                           [self purpleAccount], PURPLE_CALLBACK(chat_buddy_joined));
}

- (void)configurePurpleAccount
{
  [super configurePurpleAccount];
  
  purple_account_set_string (account, TGP_KEY_PASSWORD_TWO_FACTOR,
                             [[self preferenceForKey:@"Telegram:"TGP_KEY_PASSWORD_TWO_FACTOR
                                               group:GROUP_ACCOUNT_STATUS]
                              UTF8String]);
  
  purple_account_set_string (account, TGP_KEY_ACCEPT_SECRET_CHATS,
                              [[self preferenceForKey:@"Telegram:"TGP_KEY_ACCEPT_SECRET_CHATS
                                                group:GROUP_ACCOUNT_STATUS]
                               UTF8String]);
  
  purple_account_set_bool (account, TGP_KEY_DISPLAY_READ_NOTIFICATIONS,
                              [[self preferenceForKey:@"Telegram:"TGP_KEY_DISPLAY_READ_NOTIFICATIONS
                                                group:GROUP_ACCOUNT_STATUS]
                               boolValue]);
  
  purple_account_set_bool (account, TGP_KEY_SEND_READ_NOTIFICATIONS,
                           [[self preferenceForKey:@"Telegram:"TGP_KEY_SEND_READ_NOTIFICATIONS
                                             group:GROUP_ACCOUNT_STATUS]
                            boolValue]);
  
  purple_account_set_bool (account, TGP_KEY_HISTORY_SYNC_ALL,
                              [[self preferenceForKey:@"Telegram:"TGP_KEY_HISTORY_SYNC_ALL
                                                group:GROUP_ACCOUNT_STATUS]
                               boolValue]);
  
  purple_account_set_int (account, TGP_KEY_HISTORY_RETRIEVAL_THRESHOLD,
                              [[self preferenceForKey:@"Telegram:"TGP_KEY_HISTORY_RETRIEVAL_THRESHOLD
                                                group:GROUP_ACCOUNT_STATUS]
                               intValue]);
  
  purple_account_set_int (account, TGP_KEY_INACTIVE_DAYS_OFFLINE,
                              [[self preferenceForKey:@"Telegram:"TGP_KEY_INACTIVE_DAYS_OFFLINE
                                                group:GROUP_ACCOUNT_STATUS]
                               intValue]);
}

#pragma mark Action Menu
-(NSMenu*)actionMenuForChat:(AIChat*)chat
{
  NSArray *listObjects = nil;
  AIListObject *listObject = nil;
  
  if (listObjects.count) {
    listObject = [listObjects objectAtIndex:0];
  }
  
  NSMenu *menu = [adium.menuController
            contextualMenuWithLocations: [NSArray arrayWithObjects:
            [NSNumber numberWithInteger: Context_GroupChat_Manage],
            [NSNumber numberWithInteger: Context_Group_Manage],
            [NSNumber numberWithInteger: Context_GroupChat_Action],
            nil] forChat: chat];
  [menu addItem:[NSMenuItem separatorItem]];

  [menu addItemWithTitle:@"Invite users by link..."
                  target:self
                  action:@selector(addUserByLink)
           keyEquivalent:@""
                     tag:0];
  
  [menu addItemWithTitle:@"Delete and exit..."
                  target:self
                  action:@selector(deleteAndExitChat)
           keyEquivalent:@""
                     tag:0];
  
  return menu;
}

- (void)addUserByLink
{
  connection_data *conn = purple_connection_get_protocol_data (purple_account_get_connection(account));
  AIChat *chat = adium.interfaceController.activeChat;
  if (chat) {
    export_chat_link_checked (conn->TLS, [chat.name UTF8String]);
  }
}

- (void)deleteAndExitChat
{
  connection_data *conn = purple_connection_get_protocol_data (purple_account_get_connection(account));
  AIChat *chat = adium.interfaceController.activeChat;
  if (chat) {
    PurpleChat *purpleChat = purple_blist_find_chat (conn->pa, [chat.name UTF8String]);
    if (purpleChat) {
      leave_and_delete_chat ((PurpleBlistNode *)purpleChat, NULL);
    }
  }
}

#pragma mark File transfer
- (BOOL)canSendOfflineMessageToContact:(AIListContact *)inContact
{
	return YES;
}

- (void)beginSendOfFileTransfer:(ESFileTransfer *)fileTransfer
{
  [super _beginSendOfFileTransfer:fileTransfer];
}

- (void)acceptFileTransferRequest:(ESFileTransfer *)fileTransfer
{
  [super acceptFileTransferRequest:fileTransfer];
}

- (void)rejectFileReceiveRequest:(ESFileTransfer *)fileTransfer
{
  [super rejectFileReceiveRequest:fileTransfer];
}

- (void)cancelFileTransfer:(ESFileTransfer *)fileTransfer
{
  [super cancelFileTransfer:fileTransfer];
}

#pragma mark Group Chats
void chat_buddy_joined (PurpleConversation *conv, const char *name,
                        PurpleConvChatBuddyFlags flags,
                        gboolean new_arrival, void *data) {
  const char *proto = purple_conversation_get_account (conv)->protocol_id;
  if (! proto || 0 != strcmp ("prpl-telegram", proto)) {
    return;
  }
  
  TelegramAccount *_self = (__bridge TelegramAccount *)(data);
  connection_data *conn = purple_connection_get_protocol_data(
                            purple_account_get_connection(purple_conversation_get_account(conv)));
  assert (conn);
  if (!name || !conv->name) {
    return;
  }
  
  tgl_peer_t *P = tgl_peer_get (conn->TLS, TGL_MK_USER(atoi(name)));
  AIChat *chat = [_self chatWithName:[NSString stringWithUTF8String:conv->name] identifier:nil];
  if (P && chat) {
    AIListObject *dummy = [[AIListObject alloc]
                           initWithUID:[NSString stringWithUTF8String:name]
                           service:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      if (P->print_name) {
        [chat setAlias:[NSString stringWithUTF8String:P->print_name]
            forContact:dummy];
        [chat resortParticipants];
      }
    });
  }
}

/*!
 * @brief Re-create the chat's join options.
 */
- (NSDictionary *)extractChatCreationDictionaryFromConversation:(PurpleConversation *)conv
{
  connection_data *conn = purple_connection_get_protocol_data (purple_conversation_get_gc (conv));
  
  const char *name = purple_conversation_get_name (conv);
  tgl_peer_t *P = tgl_peer_get_by_name (conn->TLS, purple_conversation_get_title (conv));
  if (P) {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithFormat:@"%d", tgl_get_peer_id(P->id)], @"id",
            [NSString stringWithUTF8String: name], @"subject",
            [NSString stringWithFormat:@"%d", P->chat.admin_id], @"owner",
            nil];
  }
  return nil;
}

@end
