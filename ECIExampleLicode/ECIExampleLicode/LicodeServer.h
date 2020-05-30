//
//  LicodeServer.h
//  ECIExample
//
//  Created by Alvaro Gil on 9/4/15.
//  Copyright (c) 2015 Alvaro Gil. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LicodeServer : NSObject


/// 获取一个 LicodeServer 实例
+ (instancetype)sharedInstance;

/// 获取多人视频会话协议
/// @param username 用户名
/// @param completion 获取后的回调
- (void)obtainMultiVideoConferenceToken:(NSString *)username
                             completion:(void(^)(BOOL result, NSString *token))completion;

@end
