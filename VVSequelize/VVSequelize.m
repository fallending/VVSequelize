//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

@interface VVSequelizeInnerPrivate: NSObject

@property (nonatomic, assign) NSInteger loglevel;        ///< 调试信息
@property (nonatomic, assign) BOOL      useCache;        ///< 是否使用缓存

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

+ (NSInteger)loglevel{
    return [[self class] innerPrivate].loglevel;
}

+ (void)setLoglevel:(NSInteger)loglevel{
    [[self class] innerPrivate].loglevel = loglevel;
}

+ (BOOL)useCache{
    return [[self class] innerPrivate].useCache;
}

+(void)setUseCache:(BOOL)useCache{
    [[self class] innerPrivate].useCache = useCache;
}

//MARK: - 调试信息打印
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...{
    NSInteger loglevel = [[self class] innerPrivate].loglevel;
    if(loglevel > 0 && loglevel >= level){
        va_list args;
        va_start(args, fmt);
        NSString *string = fmt? [[NSString alloc] initWithFormat:fmt locale:[NSLocale currentLocale] arguments:args]:fmt;
        va_end(args);
        NSLog(@"VVSequelize->%@", string);
    }
}

@end
