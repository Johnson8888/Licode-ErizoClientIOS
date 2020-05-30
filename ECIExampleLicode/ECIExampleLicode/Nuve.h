//
//  Nuve.h
//  ECIExampleLicode
//
//  Created by Alvaro Gil on 3/6/17.
//  Copyright © 2017 Alvaro Gil. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RoomType) {
    RoomTypeP2P, ///  P2P房间
    RoomTypeMCU, ///  MCU房间
};

/// HTTP 请求的回调
typedef void(^NuveHTTPCallback)(BOOL success, id data);
/// 创建房间成功后的回调
typedef void(^NuveCreateRoomCallback)(BOOL success, NSString *roomId, BOOL p2p);
/// 创建Token成功后的回调
typedef void(^NuveCreateTokenCallback)(BOOL success, NSString *token);
/// 获取所有房间称呼后的回调
typedef void(^NuveListRoomsCallback)(BOOL success, NSArray *rooms);
/// Presenter 角色
static NSString *const kLicodePresenterRole = @"presenter";


@interface Nuve : NSObject

/// 获取一个 Nuve实例
+ (instancetype)sharedInstance;

/// 获取当前房间列表
/// @param completion 回去成功后的回调
- (void)listRoomsWithCompletion:(NuveListRoomsCallback)completion;

/// 创建一个房间
/// @param roomName 房间名字
/// @param roomType 房间类型
/// @param options 配置参数
/// @param completion 创建成功后的回调
- (void)createRoom:(NSString *)roomName
          roomType:(RoomType)roomType
           options:(NSDictionary *)options
        completion:(NuveCreateRoomCallback)completion;


/// 由房间Id生成Token
/// @param roomId 房间Id
/// @param username 用户名字
/// @param role 角色
/// @param completion 创建成功后的回调
- (void)createTokenForRoomId:(NSString *)roomId
                    username:(NSString *)username
                        role:(NSString *)role
                  completion:(NuveCreateTokenCallback)completion;



/// 创建房间和Token
/// @param roomName 房间名字
/// @param roomType 房间类型
/// @param username 用户名自
/// @param completion 完成后的回调
- (void)createRoomAndCreateToken:(NSString *)roomName
                        roomType:(RoomType)roomType
                        username:(NSString *)username
                      completion:(NuveCreateTokenCallback)completion;

@end
