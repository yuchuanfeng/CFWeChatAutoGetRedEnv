//
//  autoGetRedEnv.mm
//  autoGetRedEnv
//
//  Created by 于传峰 on 2016/12/6.
//  Copyright (c) 2016年 __MyCompanyName__. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#import <Foundation/Foundation.h>
#import "CaptainHook/CaptainHook.h"
#include <notify.h> // not required; for examples only
#import <objc/runtime.h>
#import <objc/message.h>

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()


/**
 *  插件功能
 */
static int const kCloseRedEnvPlugin = 0;
static int const kOpenRedEnvPlugin = 1;
static int const kCloseRedEnvPluginForMyself = 2;
static int const kCloseRedEnvPluginForMyselfFromChatroom = 3;

//0：关闭红包插件
//1：打开红包插件
//2: 不抢自己的红包
//3: 不抢群里自己发的红包
static int HBPliginType = 1;
static NSString* const HBTypeSetting = @"HBPliginType";

//#define SAVESETTINGS(key, value) { \
//NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); \
//NSString *docDir = [paths objectAtIndex:0]; \
//if (!docDir){ return;} \
//NSMutableDictionary *dict = [NSMutableDictionary dictionary]; \
//NSString *path = [docDir stringByAppendingPathComponent:@"HBPluginSettings.txt"]; \
//[dict setObject:value forKey:key]; \
//[dict writeToFile:path atomically:YES]; \
//}

//NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//NSString *docDir = [paths objectAtIndex:0];
//if (!docDir){ return;}
//NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//NSString *path = [docDir stringByAppendingPathComponent:@"HBPluginSettings.txt"];
//[dict setObject:value forKey:key];
//[dict writeToFile:path atomically:YES];
//}

CHDeclareClass(CMessageMgr);
CHDeclareClass(JailBreakHelper);

// - (void)AsyncOnAddMsg:(id)arg1 MsgWrap:(id)arg2;
// - (void)AsyncOnDelMsg:(id)arg1 MsgWrap:(id)arg2
// - (void)onRevokeMsg:(id)arg1;
/*
 - (BOOL)HasInstallJailbreakPluginInvalidIAPPurchase;
 - (BOOL)HasInstallJailbreakPlugin:(id)arg1;
 - (BOOL)IsJailBreak;
 */
#pragma mark - 越狱检测
CHMethod(0, BOOL, JailBreakHelper, HasInstallJailbreakPluginInvalidIAPPurchase)
{
    return NO;
}

CHMethod(0, BOOL, JailBreakHelper, IsJailBreak)
{
    return NO;
}
CHMethod(1, BOOL, JailBreakHelper, HasInstallJailbreakPlugin, id, arg1)
{
    return NO;
}


#pragma mark - 防撤回
CHMethod(1, void, CMessageMgr, onRevokeMsg, id, arg1)
{

    NSLog(@"\n>>>>>> onRevokeMsg <<<<<< \n arg1:[%@]%@ ", [arg1 class], arg1);
}

#pragma mark - 消息
CHMethod(2, void, CMessageMgr, AsyncOnAddMsg, id, arg1, MsgWrap, id, arg2)
{
    CHSuper(2,  CMessageMgr, AsyncOnAddMsg, arg1, MsgWrap, arg2);
    
    Ivar uiMessageTypeIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_uiMessageType");
    ptrdiff_t offset = ivar_getOffset(uiMessageTypeIvar);
    unsigned char *stuffBytes = (unsigned char *)(__bridge void *)arg2;
    NSUInteger* messageTypePoint = (NSUInteger *)(stuffBytes + offset);
    NSUInteger m_uiMessageType = * messageTypePoint;
    
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    id m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    
    Ivar nsContentIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsContent");
    id m_nsContent = object_getIvar(arg2, nsContentIvar);
    

    NSLog(@"\n>>>>>> AsyncOnAddMsg  MsgWrap <<<<<< \n arg1:[%@]%@ arg2:[%@]%@ \n messageType:%zd  fromUser:%@ content:%@ ", [arg1 class], arg1, [arg2 class], arg2, m_uiMessageType, m_nsFromUsr, m_nsContent);

    
    
    
    switch(m_uiMessageType) {
        case 1:
        {
            //普通消息
            //红包插件功能
            //0：关闭红包插件
            //1：打开红包插件
            //2: 不抢自己的红包
            //3: 不抢群里自己发的红包
            //微信的服务中心
            Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            IMP impMMSC = method_getImplementation(methodMMServiceCenter);
            id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            //通讯录管理器
            id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
            id selfContact = objc_msgSend(contactManager, @selector(getSelfContact));
            
            Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
            id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
            BOOL isMesasgeFromMe = NO;
            if ([m_nsFromUsr isEqualToString:m_nsUsrName]) {
                //发给自己的消息
                isMesasgeFromMe = YES;
            }
            
            if (isMesasgeFromMe)
            {
                if ([m_nsContent rangeOfString:@"打开红包插件"].location != NSNotFound)
                {
                    HBPliginType = kOpenRedEnvPlugin;
                }
                else if ([m_nsContent rangeOfString:@"关闭红包插件"].location != NSNotFound)
                {
                    HBPliginType = kCloseRedEnvPlugin;
                }
                else if ([m_nsContent rangeOfString:@"关闭抢自己红包"].location != NSNotFound)
                {
                    HBPliginType = kCloseRedEnvPluginForMyself;
                }
                else if ([m_nsContent rangeOfString:@"关闭抢自己群红包"].location != NSNotFound)
                {
                    HBPliginType = kCloseRedEnvPluginForMyselfFromChatroom;
                }
                
                [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:HBPliginType] forKey:HBTypeSetting];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
            break;
        case 49: {
            // 49=红包
            NSNumber* type = [[NSUserDefaults standardUserDefaults] objectForKey:HBTypeSetting];
            if (type)
            {
                HBPliginType = [type intValue];
            }
            if(kCloseRedEnvPlugin == HBPliginType)
                break;
            
            //微信的服务中心
            Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            IMP impMMSC = method_getImplementation(methodMMServiceCenter);
            id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            //红包控制器
            id logicMgr = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("WCRedEnvelopesLogicMgr"));
            //通讯录管理器
            id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
            
            Method methodGetSelfContact = class_getInstanceMethod(objc_getClass("CContactMgr"), @selector(getSelfContact));
            IMP impGS = method_getImplementation(methodGetSelfContact);
            id selfContact = impGS(contactManager, @selector(getSelfContact));
            
            Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
            id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
            BOOL isMesasgeFromMe = NO;
            BOOL isChatroom = NO;
            if ([m_nsFromUsr isEqualToString:m_nsUsrName]) {
                isMesasgeFromMe = YES;
            }
            if ([m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound)
            {
                isChatroom = YES;
            }
            if (isMesasgeFromMe && kCloseRedEnvPluginForMyself == HBPliginType && !isChatroom) {
                //不抢自己的红包
                break;
            }
            else if(isMesasgeFromMe && kCloseRedEnvPluginForMyselfFromChatroom == HBPliginType && isChatroom)
            {
                //不抢群里自己的红包
                break;
            }
            
            if ([m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound)
            {
                NSString *nativeUrl = m_nsContent;
                NSRange rangeStart = [m_nsContent rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao"];
                if (rangeStart.location != NSNotFound)
                {
                    NSUInteger locationStart = rangeStart.location;
                    nativeUrl = [nativeUrl substringFromIndex:locationStart];
                }
                
                NSRange rangeEnd = [nativeUrl rangeOfString:@"]]"];
                if (rangeEnd.location != NSNotFound)
                {
                    NSUInteger locationEnd = rangeEnd.location;
                    nativeUrl = [nativeUrl substringToIndex:locationEnd];
                }
                
                NSString *naUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                
                NSArray *parameterPairs =[naUrl componentsSeparatedByString:@"&"];
                
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
                for (NSString *currentPair in parameterPairs) {
                    NSRange range = [currentPair rangeOfString:@"="];
                    if(range.location == NSNotFound)
                        continue;
                    NSString *key = [currentPair substringToIndex:range.location];
                    NSString *value =[currentPair substringFromIndex:range.location + 1];
                    [parameters setObject:value forKey:key];
                }
                
                //红包参数
                NSMutableDictionary *params = [@{} mutableCopy];
                
                [params setObject:parameters[@"msgtype"]?:@"null" forKey:@"msgType"];
                [params setObject:parameters[@"sendid"]?:@"null" forKey:@"sendId"];
                [params setObject:parameters[@"channelid"]?:@"null" forKey:@"channelId"];
                
                id getContactDisplayName = objc_msgSend(selfContact, @selector(getContactDisplayName));
                id m_nsHeadImgUrl = objc_msgSend(selfContact, @selector(m_nsHeadImgUrl));
                
                [params setObject:getContactDisplayName forKey:@"nickName"];
                [params setObject:m_nsHeadImgUrl forKey:@"headImg"];
                [params setObject:[NSString stringWithFormat:@"%@", nativeUrl]?:@"null" forKey:@"nativeUrl"];
                [params setObject:m_nsFromUsr?:@"null" forKey:@"sessionUserName"];
                
                if (kCloseRedEnvPlugin != HBPliginType) {
                    //自动抢红包
                    ((void (*)(id, SEL, NSMutableDictionary*))objc_msgSend)(logicMgr, @selector(OpenRedEnvelopesRequest:), params);
                }
                return;
            }
            
            break;
        }
            
        default:
            break;
    }
    
}

__attribute__((constructor)) static void entry()
{
    CHLoadLateClass(CMessageMgr);
    CHLoadLateClass(JailBreakHelper);
    
    CHClassHook(2, CMessageMgr, AsyncOnAddMsg, MsgWrap);
    CHClassHook(1, CMessageMgr, onRevokeMsg);
    CHClassHook(0, JailBreakHelper, HasInstallJailbreakPluginInvalidIAPPurchase);
    CHClassHook(0, JailBreakHelper, IsJailBreak);
    CHClassHook(1, JailBreakHelper, HasInstallJailbreakPlugin);
    
}
