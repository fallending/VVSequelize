//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

@interface VVSequelizeInnerPrivate: NSObject
@property (nonatomic, assign) BOOL useCache;  ///< 是否使用缓存
@property (nonatomic, copy  ) void (^trace)(NSString *, NSArray *, id); ///< 跟踪SQL执行
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

+ (void)setTrace:(void (^)(NSString *, NSArray *, id))trace{
    [self innerPrivate].trace = trace;
}

+ (void (^)(NSString *, NSArray *, id))trace{
    return [self innerPrivate].trace;
}

+ (BOOL)useCache{
    return [self innerPrivate].useCache;
}

+(void)setUseCache:(BOOL)useCache{
    [self innerPrivate].useCache = useCache;
}

@end
