//
//  VVDatabase+Additions.m
//  VVSequelize
//
//  Created by Valo on 2019/3/27.
//

#import "VVDatabase+Additions.h"

static const char *const VVDBReadQueueLabel = "com.valo.sequelize.read";
static const char *const VVDBWriteQueueLabel = "com.valo.sequelize.write";
static const void *const VVDBSpecificKey = (const void *)&VVDBSpecificKey;

@implementation VVDatabase (Additions)
// MARK: - pool
+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
{
    return [self databaseInPoolWithPath:path flags:0 encrypt:nil];
}

+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags
{
    return [self databaseInPoolWithPath:path flags:flags encrypt:nil];
}

+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags
                               encrypt:(nullable NSString *)key
{
    static NSMapTable *_pool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _pool = [NSMapTable strongToWeakObjectsMapTable];
    });
    NSString *udid = [self udidWithPath:path flags:flags encryptKey:key];
    VVDatabase *db = [_pool objectForKey:udid];
    if (!db) {
        db = [self databaseWithPath:path flags:flags encrypt:key];
        [_pool setObject:db forKey:udid];
    }
    return db;
}

+ (NSString *)udidWithPath:(NSString *)path flags:(int)flags encryptKey:(NSString *)key
{
    NSString *aPath = path ? : VVDBPathTemporary;
    int aFlags = flags | VVDBEssentialFlags;
    NSString *aKey = key ? : @"";
    return [NSString stringWithFormat:@"%@|%@|%@", aPath, @(aFlags), aKey];
}

// MARK: - queue
+ (dispatch_queue_t)readQueue
{
    static dispatch_queue_t _readQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _readQueue = dispatch_queue_create(VVDBReadQueueLabel, DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_set_specific(_readQueue, VVDBSpecificKey, (__bridge void *)_readQueue, NULL);
    });
    return _readQueue;
}

+ (dispatch_queue_t)writeQueue
{
    static dispatch_queue_t _writeQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _writeQueue = dispatch_queue_create(VVDBWriteQueueLabel, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_writeQueue, VVDBSpecificKey, (__bridge void *)_writeQueue, NULL);
    });
    return _writeQueue;
}

+ (void)syncRead:(void (^)(void))block
{
    [self queue:[self readQueue] sync:block];
}

+ (void)asyncRead:(void (^)(void))block
{
    [self queue:[self readQueue] async:block];
}

+ (void)syncWrite:(void (^)(void))block
{
    [self queue:[self writeQueue] sync:block];
}

+ (void)asyncWrite:(void (^)(void))block
{
    [self queue:[self writeQueue] async:block];
}

+ (void)queue:(dispatch_queue_t)queue sync:(void (^)(void))block
{
    if (!block) return;
    if (dispatch_get_specific(VVDBSpecificKey) == (__bridge void *)queue) {
        block();
    } else {
        dispatch_sync(queue, block);
    }
}

+ (void)queue:(dispatch_queue_t)queue async:(void (^)(void))block
{
    if (!block) return;
    if (dispatch_get_specific(VVDBSpecificKey) == (__bridge void *)queue) {
        block();
    } else {
        dispatch_async(queue, block);
    }
}

@end
