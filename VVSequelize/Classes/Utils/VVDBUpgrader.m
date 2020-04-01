//
//  VVDBUpgrader.m
//  VVSequelize
//
//  Created by Valo on 2018/8/11.
//

#import "VVDBUpgrader.h"

NSString *const VVDBUpgraderLastVersionKey = @"VVDBUpgraderLastVersionKey";

@interface VVDBUpgradeItem : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) void (^ handler)(NSProgress *);
@property (nonatomic, copy) NSString *version;
@property (nonatomic, assign) NSUInteger stage;
@property (nonatomic, strong) NSProgress *progress;

- (NSComparisonResult)compare:(VVDBUpgradeItem *)other;

+ (NSComparisonResult)compareVersion:(NSString *)version1 with:(NSString *)version2;

@end

@implementation VVDBUpgradeItem

- (instancetype)init
{
    self = [super init];
    if (self) {
        _progress = [NSProgress progressWithTotalUnitCount:100];
    }
    return self;
}

- (NSComparisonResult)compare:(VVDBUpgradeItem *)other {
    NSComparisonResult result = [VVDBUpgradeItem compareVersion:self.version with:other.version];
    if (result == NSOrderedSame) {
        result = self.stage < other.stage ? NSOrderedAscending : (self.stage == other.stage ? NSOrderedSame : NSOrderedDescending);
    }
    return result;
}

+ (NSComparisonResult)compareVersion:(NSString *)version1 with:(NSString *)version2
{
    NSCharacterSet *chset = [NSCharacterSet characterSetWithCharactersInString:@".-_"];
    NSArray *array1 = [version1 componentsSeparatedByCharactersInSet:chset];
    NSArray *array2 = [version2 componentsSeparatedByCharactersInSet:chset];
    NSUInteger count = MIN(array1.count, array2.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSString *str1 = array1[i];
        NSString *str2 = array2[i];
        NSComparisonResult ret = [str1 compare:str2];
        if (ret != NSOrderedSame) {
            return ret;
        }
    }
    return array1.count < array2.count ? NSOrderedAscending :
           array1.count == array2.count ? NSOrderedSame : NSOrderedDescending;
}

@end

@interface VVDBUpgrader ()
@property (nonatomic, strong) NSMutableArray<VVDBUpgradeItem *> *items;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSArray *> *stageItems;
@property (nonatomic, strong) NSArray<NSNumber *> *stages;
@property (nonatomic, assign) BOOL pretreated;
@end

@implementation VVDBUpgrader

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithVersionKey:(NSString *)key
{
    self = [super init];
    if (self) {
        _versionKey = key;
        [self setup];
    }
    return self;
}

- (void)setup
{
    _items = [NSMutableArray array];
    _progress = [NSProgress progressWithTotalUnitCount:100];
    _versionKey = _versionKey ? : VVDBUpgraderLastVersionKey;
}

- (BOOL)isUpgrading
{
    return _pretreated && _stageItems.count > 0 && _progress.completedUnitCount < _progress.totalUnitCount;
}

- (void)reset
{
    _pretreated = NO;
    _progress.completedUnitCount = 0;
    for (VVDBUpgradeItem *item in _items) {
        item.progress.completedUnitCount = 0;
    }
}

- (void)addTarget:(id)target
           action:(SEL)action
         forStage:(NSUInteger)stage
          version:(NSString *)version
{
    VVDBUpgradeItem *item = [[VVDBUpgradeItem alloc] init];
    item.target = target;
    item.action = action;
    item.stage = stage;
    item.version = version;
    [_items addObject:item];
}

- (void)addHandlerForStage:(NSUInteger)stage
                   version:(NSString *)version
                   handler:(void (^)(NSProgress *))handler
{
    VVDBUpgradeItem *item = [[VVDBUpgradeItem alloc] init];
    item.stage = stage;
    item.version = version;
    item.handler = handler;
    [_items addObject:item];
}

- (void)pretreat {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastVersion = [defaults objectForKey:_versionKey];

    [self.items sortUsingComparator:^NSComparisonResult (VVDBUpgradeItem *item1, VVDBUpgradeItem *item2) {
        return [item1 compare:item2];
    }];

    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (VVDBUpgradeItem *item in _items) {
        //upgrade from last version
        if ([VVDBUpgradeItem compareVersion:item.version with:lastVersion] <= NSOrderedSame) {
            continue;
        }
        //stage
        NSNumber *stage = @(item.stage);
        NSMutableArray *array = dic[stage];
        if (!array) {
            array = [NSMutableArray array];
            dic[stage] = array;
        }
        [array addObject:item];
    }

    //stage sorting
    NSMutableArray *stages = [dic.allKeys mutableCopy];
    [stages sortUsingComparator:^NSComparisonResult (NSNumber *stage1, NSNumber *stage2) {
        return [stage1 unsignedIntegerValue] < [stage2 unsignedIntegerValue] ? NSOrderedAscending : NSOrderedDescending;
    }];

    for (NSNumber *stage in stages) {
        //add stage progress
        NSProgress *stageProgress = [NSProgress progressWithTotalUnitCount:100];
        [self.progress addChild:stageProgress withPendingUnitCount:100 / stages.count];
        //items sorting
        NSMutableArray *array = dic[stage];
        [array sortUsingComparator:^NSComparisonResult (VVDBUpgradeItem *item1, VVDBUpgradeItem *item2) {
            return [VVDBUpgradeItem compareVersion:item1.version with:item2.version];
        }];
        //add item progress
        for (VVDBUpgradeItem *item in array) {
            [stageProgress addChild:item.progress withPendingUnitCount:stageProgress.totalUnitCount / array.count];
        }
    }

    self.stageItems = [dic copy];
    self.stages = [stages copy];

    _pretreated = YES;
}

- (BOOL)needUpgrade
{
    if (!_pretreated) {
        [self pretreat];
    }
    return self.stageItems.count > 0;
}

- (void)upgradeAll
{
    if (!_pretreated) {
        [self pretreat];
    }

    for (NSNumber *stage in self.stages) {
        [self upgradeStage:stage.unsignedIntegerValue];
    }
}

- (void)upgradeStage:(NSInteger)stage
{
    [self upgradeStage:stage versionFrom:nil to:nil];
}

- (void)upgradeStage:(NSInteger)stage versionFrom:(NSString *)from to:(NSString *)to
{
    if (!_pretreated) {
        [self pretreat];
    }

    NSArray *items = self.stageItems[@(stage)];
    NSMutableArray *todos = [NSMutableArray array];

    for (VVDBUpgradeItem *item in items) {
        if ((from && [VVDBUpgradeItem compareVersion:item.version with:from] <= NSOrderedSame) ||
            (to && [VVDBUpgradeItem compareVersion:item.version with:to] > NSOrderedSame)) {
            continue;
        }
        [todos addObject:item];
    }

    if (todos.count == 0) return;
    for (VVDBUpgradeItem *item in todos) {
        if (item.target && item.action) {
            if ([item.target respondsToSelector:item.action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [item.target performSelector:item.action withObject:item.progress];
#pragma clang diagnostic pop
            }
        } else if (item.handler) {
            item.handler(item.progress);
        }
        item.progress.completedUnitCount = item.progress.totalUnitCount;
    }

    //record last version
    if (stage == self.stages.lastObject.unsignedIntegerValue) {
        VVDBUpgradeItem *last = [self.stageItems[@(stage)] lastObject];
        if ([last isEqual:todos.lastObject]) {
            self.progress.completedUnitCount = self.progress.totalUnitCount;
            [[NSUserDefaults standardUserDefaults] setObject:self.items.lastObject.version forKey:_versionKey];
        }
    }
}

@end
