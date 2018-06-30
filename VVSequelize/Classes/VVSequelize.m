//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

static VVLogLevel _verbose = VVLogLevelNone;

static id<VVSequelizeBridge> _bridge = nil;

@implementation VVSequelize

#pragma mark - 调试信息打印
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...{
    if(_verbose > 0 && _verbose >= level){
        va_list args;
        va_start(args, fmt);
        NSString *string = fmt? [[NSString alloc] initWithFormat:fmt locale:[NSLocale currentLocale] arguments:args]:fmt;
        va_end(args);
        NSLog(@"%@", string);
    }
}

+ (BOOL)verbose{
    return _verbose;
}

+ (void)setVerbose:(VVLogLevel)verbose{
    _verbose = verbose;
}

- (id<VVSequelizeBridge>)bridge{
    return _bridge;
}

+ (void)setSharedBridge:(id<VVSequelizeBridge>)bridge{
    _bridge = bridge;
}

@end
