//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

static NSInteger _loglevel = 0;
static id<VVSequelizeBridge> _bridge = nil;

@implementation VVSequelize

@dynamic bridge;

#pragma mark - 调试信息打印
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...{
    if(_loglevel > 0 && _loglevel >= level){
        va_list args;
        va_start(args, fmt);
        NSString *string = fmt? [[NSString alloc] initWithFormat:fmt locale:[NSLocale currentLocale] arguments:args]:fmt;
        va_end(args);
        NSLog(@"%@", string);
    }
}

+ (NSInteger)loglevel{
    return _loglevel;
}

+ (void)setLoglevel:(NSInteger)loglevel{
    _loglevel = loglevel;
}

- (id<VVSequelizeBridge>)bridge{
    NSAssert(_bridge != nil, @"Please set up bridge first!");
    return _bridge;
}

+ (void)setBridge:(id<VVSequelizeBridge>)bridge{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        VVLog(1,@"Bridge can be set only once!");
        _bridge = bridge;
    });
}

@end
