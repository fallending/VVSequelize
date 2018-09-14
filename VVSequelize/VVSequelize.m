//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

@interface VVSequelizeInnerPrivate: NSObject
@property (nonatomic, strong) Class<VVSQLiteDB> dbClass; ///< 设置sqlite3封装类
@property (nonatomic, assign) BOOL useCache;             ///< 是否使用缓存
@property (nonatomic, copy  ) void (^trace)(NSString *, NSArray *, id, NSError *); ///< 跟踪SQL执行
@end

@implementation VVSequelizeInnerPrivate

@end

@implementation VVSequelize

+ (VVSequelizeInnerPrivate *)innerPrivate{
    static VVSequelizeInnerPrivate *_innerPrivate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _innerPrivate = [[VVSequelizeInnerPrivate alloc] init];
        _innerPrivate.useCache = YES; //默认使用cache
    });
    return _innerPrivate;
}

//MARK: - 全局设置

+ (Class<VVSQLiteDB>)dbClass{
    return [self innerPrivate].dbClass;
}

+ (void)setDbClass:(Class<VVSQLiteDB>)dbClass{
    [self innerPrivate].dbClass = dbClass;
}

+ (BOOL)useCache{
    return [self innerPrivate].useCache;
}

+(void)setUseCache:(BOOL)useCache{
    [self innerPrivate].useCache = useCache;
}

+ (void (^)(NSString *, NSArray *, id, NSError *))trace{
    return [self innerPrivate].trace;
}

+ (void)setTrace:(void (^)(NSString *, NSArray *, id, NSError *))trace{
    [self innerPrivate].trace = trace;
}

@end
