//
//  VVDBUpgrader.m
//  VVSequelize
//
//  Created by Valo on 2018/8/11.
//

#import "VVDBUpgrader.h"

NSString *const VVDBUpgraderLastVersionKey = @"VVDBUpgraderLastVersionKey";
NSString *const VVDBUpgraderCompletedInfoSuffix = @"-lastCompleted";

@interface NSString (VVDBUpgrader)
+ (NSComparisonResult)compareVersion:(NSString *)version1 with:(NSString *)version2;
@end

@implementation NSString (VVDBUpgrader)

+ (NSComparisonResult)compareVersion:(NSString *)version1 with:(NSString *)version2
{
    if ([version1 isEqualToString:version2]) return NSOrderedSame;

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

@implementation VVDBUpgradeItem

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage
                            target:(id)target
                            action:(SEL)action
{
    VVDBUpgradeItem *item = [[VVDBUpgradeItem alloc] initWithIdentifier:identifier version:version stage:stage];
    item.target = target;
    item.action = action;
    return item;
}

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage
                           handler:(BOOL (^)(VVDBUpgradeItem *))handler
{
    VVDBUpgradeItem *item = [[VVDBUpgradeItem alloc] initWithIdentifier:identifier version:version stage:stage];
    item.handler = handler;
    return item;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                             stage:(NSUInteger)stage
{
    self = [super init];
    if (self) {
        _identifier = identifier;
        _version = version;
        _stage = stage;
        _priority = 0.5;
        _weight = 1.0;
    }
    return self;
}

- (void)reset
{
    self.progress = 0.0;
}

- (void)setWeight:(CGFloat)weight
{
    _weight = MAX(1.0, weight);
}

- (void)setPriority:(CGFloat)priority
{
    _priority = MAX(0.0, MIN(1.0, priority));
}

- (void)setProgress:(CGFloat)progress
{
    _progress = MAX(0.0, MIN(100.0, progress));
}

- (NSComparisonResult)compare:(VVDBUpgradeItem *)other
{
    NSComparisonResult result = self.stage < other.stage ? NSOrderedAscending : (self.stage == other.stage ? NSOrderedSame : NSOrderedDescending);
    if (result == NSOrderedSame) {
        result = [NSString compareVersion:self.version with:other.version];
    }
    if (result == NSOrderedSame) {
        result = self.priority < other.priority ? NSOrderedAscending : (self.priority == other.priority ? NSOrderedSame : NSOrderedDescending);
    }
    return result;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"id:'%@', stage:%@, version:'%@', priority:%.2f, weight:%.2f, progress:%.2f", _identifier, @(_stage), _version, _priority, _weight, _progress];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    VVDBUpgradeItem *item = [[[self class] allocWithZone:zone] init];
    item.identifier = self.identifier;
    item.stage = self.stage;
    item.version = self.version;
    item.handler = self.handler;
    item.target = self.target;
    item.action = self.action;
    item.priority = self.priority;
    item.weight = self.weight;
    item.progress = 0.0;
    return item;
}

@end

@interface VVDBUpgrader ()
@property (nonatomic, copy) NSString *lastUpdatedVersion;
@property (nonatomic, copy) NSString *completedInfoKey;
@property (nonatomic, copy) NSMutableDictionary<NSString *, NSNumber *> *completedInfo;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<VVDBUpgradeItem *> *> *stageItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *versions;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *stages;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<VVDBUpgradeItem *> *> *upgradeItems;
@property (nonatomic, assign) BOOL pretreated;
@property (nonatomic, assign, getter = isUpgrading) BOOL upgrading;
@end

@implementation VVDBUpgrader

- (instancetype)init
{
    self = [super init];
    if (self) {
        _stageItems = [NSMutableDictionary dictionary];
        _versions = [NSMutableSet set];
        _stages = [NSMutableSet set];
        _progress = [NSProgress progressWithTotalUnitCount:100];
        _versionKey = VVDBUpgraderLastVersionKey;
        _completedInfoKey = [_versionKey stringByAppendingString:VVDBUpgraderCompletedInfoSuffix];
    }
    return self;
}

- (void)setVersionKey:(NSString *)versionKey
{
    _versionKey = versionKey;
    _completedInfoKey = [_versionKey stringByAppendingString:VVDBUpgraderCompletedInfoSuffix];
    _completedInfo = nil;
    _lastUpdatedVersion = nil;
}

- (NSString *)lastUpdatedVersion
{
    if (!_lastUpdatedVersion) {
        _lastUpdatedVersion = [[NSUserDefaults standardUserDefaults] stringForKey:_versionKey];
    }
    return _lastUpdatedVersion;
}

- (NSMutableDictionary<NSString *, NSNumber *> *)completedInfo
{
    if (!_completedInfo) {
        NSDictionary *info = [[NSUserDefaults standardUserDefaults] dictionaryForKey:_completedInfoKey];
        _completedInfo = [(info ? : @{}) mutableCopy];
    }
    return _completedInfo;
}

- (void)reset
{
    if (_upgrading) return;
    _pretreated = NO;
    _progress.completedUnitCount = 0;
    for (NSMutableArray<VVDBUpgradeItem *> *items in self.stageItems.allValues) {
        for (VVDBUpgradeItem *item in items) {
            [item reset];
        }
    }
}

- (void)addItem:(VVDBUpgradeItem *)item
{
    [self addItem:item to:self.stageItems];
    [self.versions addObject:item.version];
    [self.stages addObject:@(item.stage)];
}

- (void)addItems:(NSArray<VVDBUpgradeItem *> *)items
{
    for (VVDBUpgradeItem *item in items) {
        [self addItem:item];
    }
}

- (void)addItem:(VVDBUpgradeItem *)item to:(NSMutableDictionary<NSNumber *, NSMutableArray<VVDBUpgradeItem *> *> *)stageItems
{
    NSAssert(item.version.length > 0, @"Invalid upgrade item.");
    NSMutableArray *items = stageItems[@(item.stage)];
    if (!items) {
        items = [NSMutableArray array];
        stageItems[@(item.stage)] = items;
    }
    [items addObject:item];
}

- (void)pretreat
{
    if (_pretreated) return;
    @synchronized (self) {
        [self _pretreat];
    }
}

- (NSString *)latestVersion
{
    NSArray *versions = [self.versions.allObjects sortedArrayUsingComparator:^NSComparisonResult (NSString *v1, NSString *v2) {
        return [NSString compareVersion:v1 with:v2];
    }];
    return versions.lastObject;
}

- (void)_pretreat
{
    NSString *fromVersion = self.lastUpdatedVersion;
    NSDictionary *completedInfo = self.completedInfo;
    NSString *toVersion = [self latestVersion];
    if (!toVersion.length || (fromVersion.length && [NSString compareVersion:fromVersion with:toVersion] >= NSOrderedSame)) {
        _upgradeItems = @{}.mutableCopy;
        _pretreated = YES;
        return;
    }

    CGFloat totalWeight = 0;
    NSMutableDictionary<NSNumber *, NSMutableArray<VVDBUpgradeItem *> *> *upgradeItems = [NSMutableDictionary dictionary];
    for (NSMutableArray<VVDBUpgradeItem *> *items in self.stageItems.allValues) {
        for (VVDBUpgradeItem *item in items) {
            BOOL completed = [completedInfo[item.identifier] boolValue];
            if (completed) {
                item.progress = 100.0;
            } else {
                [self addItem:item to:upgradeItems];
                totalWeight += item.weight;
            }
        }
    }

    _progress.totalUnitCount = (int64_t)totalWeight * 100;
    _progress.completedUnitCount = 0;
    _upgradeItems = upgradeItems;
    _pretreated = YES;
}

- (BOOL)needUpgrade
{
    [self pretreat];
    return self.upgradeItems.count > 0;
}

- (void)upgradeAll
{
    [self pretreat];
    NSArray *sorted = [self.stages.allObjects sortedArrayUsingComparator:^NSComparisonResult (NSNumber *stage1, NSNumber *stage2) {
        NSUInteger s1 = stage1.unsignedIntegerValue;
        NSUInteger s2 = stage2.unsignedIntegerValue;
        return s1 < s2 ? NSOrderedAscending : (s1 > s2 ? NSOrderedDescending : NSOrderedSame);
    }];
    for (NSNumber *stage in sorted) {
        [self upgradeStage:stage.unsignedIntegerValue];
    }
}

- (void)upgradeStage:(NSUInteger)stage
{
    [self pretreat];
    NSArray<VVDBUpgradeItem *> *items = self.upgradeItems[@(stage)];
    [self upgradeItems:items];
}

- (void)upgradeItems:(NSArray<VVDBUpgradeItem *> *)items
{
    [self pretreat];
    _upgrading = YES;
    NSArray *sorted = [items sortedArrayUsingComparator:^NSComparisonResult (VVDBUpgradeItem *item1, VVDBUpgradeItem *item2) {
        return [item1 compare:item2];
    }];

    for (VVDBUpgradeItem *item in sorted) {
        [item addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:nil];
    }

    for (VVDBUpgradeItem *item in sorted) {
        BOOL ret = [self upgradeItem:item];
        if (ret) {
            [self completeItem:item];
        }
    }
    _upgrading = NO;
}

- (BOOL)upgradeItem:(VVDBUpgradeItem *)item
{
    if (item.progress >= 100.0) return YES;
    BOOL ret = NO;
    if (item.target && item.action) {
        if ([item.target respondsToSelector:item.action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            ret = [[item.target performSelector:item.action withObject:item] boolValue];
#pragma clang diagnostic pop
        }
    } else if (item.handler) {
        ret = item.handler(item);
    } else {
        ret = YES;
    }
    if (ret) {
        item.progress = 100.0;
    }
    return ret;
}

- (void)completeItem:(VVDBUpgradeItem *)item
{
    [item removeObserver:self forKeyPath:@"progress"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.completedInfo[item.identifier] = @(YES);

    BOOL completedAll = YES;
    for (NSMutableArray<VVDBUpgradeItem *> *items in self.upgradeItems.allValues) {
        for (VVDBUpgradeItem *item in items) {
            if (item.progress < 100.0) {
                completedAll = NO;
                break;
            }
        }
    }
    if (completedAll) {
        NSString *latestVersion = [self latestVersion];
        [defaults setObject:latestVersion forKey:_versionKey];
        [defaults setObject:@{} forKey:_completedInfoKey];
    } else {
        [defaults setObject:self.completedInfo forKey:_completedInfoKey];
    }
    [defaults synchronize];
}

- (void)debugUpgradeItems:(NSArray<VVDBUpgradeItem *> *)items progress:(NSProgress *)progress
{
    NSMutableArray *copied = [NSMutableArray arrayWithCapacity:items.count];
    for (VVDBUpgradeItem *item in items) {
        [copied addObject:item.copy];
    }
    NSArray *sorted = [copied sortedArrayUsingComparator:^NSComparisonResult (VVDBUpgradeItem *item1, VVDBUpgradeItem *item2) {
        return [item1 compare:item2];
    }];
    int64_t totalUnitCount = 0;
    NSArray *context = @[progress, copied];
    for (VVDBUpgradeItem *item in sorted) {
        totalUnitCount += (int64_t)item.weight * 100;
        [item addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:(__bridge void *)(context)];
    }

    progress.totalUnitCount = totalUnitCount;
    progress.completedUnitCount = 0;
    for (VVDBUpgradeItem *item in sorted) {
        [self upgradeItem:item];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"progress"]) {
        if (context) {
            NSArray *array = (__bridge NSArray *)context;
            NSProgress *progress = array.firstObject;
            NSArray<VVDBUpgradeItem *> *items = array.lastObject;
            int64_t completedUnitCount = 0;
            for (VVDBUpgradeItem *item in items) {
                completedUnitCount += (int64_t)(item.weight * item.progress);
            }
            progress.completedUnitCount = completedUnitCount;
        } else {
            int64_t completedUnitCount = 0;
            for (NSMutableArray<VVDBUpgradeItem *> *items in self.upgradeItems.allValues) {
                for (VVDBUpgradeItem *item in items) {
                    completedUnitCount += (int64_t)(item.weight * item.progress);
                }
            }
            self.progress.completedUnitCount = completedUnitCount;
        }
    }
}

@end
