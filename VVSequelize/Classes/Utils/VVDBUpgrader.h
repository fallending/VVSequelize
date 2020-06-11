//
//  VVDBUpgrader.h
//  VVSequelize
//
//  Created by Valo on 2018/8/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// upgrade item
@interface VVDBUpgradeItem : NSObject <NSCopying>
@property (nonatomic, weak, nullable) id target;
@property (nonatomic, assign, nullable) SEL action; ///< - (BOOL)dosomething:(VVDBUpgradeItem*)item;
@property (nonatomic, copy, nullable) BOOL (^ handler)(VVDBUpgradeItem *);

@property (nonatomic, copy, nonnull) NSString *identifier; ///< set as unique
@property (nonatomic, copy, nonnull) NSString *version;
@property (nonatomic, assign) NSUInteger stage;
@property (nonatomic, assign) CGFloat priority; ///< 0.0 ~ 1.0, default is 0.5
@property (nonatomic, assign) CGFloat weight;   ///< 1.0 ~ ∞, default is 1.0
@property (nonatomic, assign) CGFloat progress; ///< 0.0 ~ 100.0

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage
                            target:(id)target
                            action:(SEL)action;

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage
                           handler:(BOOL (^)(VVDBUpgradeItem *))handler;

- (instancetype)initWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage;

/// compare with other item
- (NSComparisonResult)compare:(VVDBUpgradeItem *)other;

@end

@interface VVDBUpgrader : NSObject

/// Key to save the last upgraded version in NSUserDefaults
@property (nonatomic, copy) NSString *versionKey;

/// upgrade progress
@property (nonatomic, strong) NSProgress *progress;

/// upgrading or not
@property (nonatomic, assign, readonly) BOOL isUpgrading;

/// add upgrade item
- (void)addItem:(VVDBUpgradeItem *)item;

/// add upgrade items
- (void)addItems:(NSArray<VVDBUpgradeItem *> *)items;

/// reset upgrade progress
- (void)reset;

/// need to upgrade or not
- (BOOL)needUpgrade;

/// upgrade all stages
- (void)upgradeAll;

/// upgrade one stage
- (void)upgradeStage:(NSUInteger)stage;

/// debug upgrade items
- (void)debugUpgradeItems:(NSArray<VVDBUpgradeItem *> *)items progress:(NSProgress *)progress;

@end

NS_ASSUME_NONNULL_END
