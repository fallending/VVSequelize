//
//  VVSequelizeConst.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/11.
//

#import "VVSequelizeConst.h"

static BOOL _verbose = NO;

@implementation VVSequelizeConst

+ (void)VVVerbose:(NSString *)fmt, ...{
    if(_verbose){
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

+ (void)setVerbose:(BOOL)verbose{
    _verbose = verbose;
}

@end
