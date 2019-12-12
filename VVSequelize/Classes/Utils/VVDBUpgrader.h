//
//  VVDBUpgrader.h
//  VVDB
//
//  Created by Valo on 2018/8/11.
//

#import <Foundation/Foundation.h>

@interface VVDBUpgrader : NSObject

/**
 Key to save the last version in NSUserDefaults
 */
@property (nonatomic, copy) NSString *versionKey;

/**
 progress of upgrader
 */
@property (nonatomic, strong) NSProgress *progress;


/**
 init with last version key

 @param key last version key
 @return upgrader
 */
- (instancetype)initWithVersionKey:(NSString *)key;

/**
 add target-action

 @param target target
 @param action such as `-(void)action:(NSProgress *)progress`
 @param stage stage
 @param version version
 */
- (void)addTarget:(id)target
           action:(SEL)action
         forStage:(NSUInteger)stage
          version:(NSString *)version;

/**
 add handler

 @param stage stage
 @param version version
 @param handler upgrade hander
 */
- (void)addHandlerForStage:(NSUInteger)stage
                   version:(NSString *)version
                   handler:(void (^)(NSProgress *))handler;

/**
 if need to upgrade

 @return if need to upgrade
 */
- (BOOL)needUpgrade;


/**
 upgrade all stages
 */
- (void)upgradeAll;

/**
 upgrade one stage

 @param stage stage
 */
- (void)upgradeStage:(NSInteger)stage;

/**
 upgrade one stage, from low version to high version

 @param stage stage
 @param from low version
 @param to high version
 */
- (void)upgradeStage:(NSInteger)stage versionFrom:(NSString *)from to:(NSString *)to;

@end
