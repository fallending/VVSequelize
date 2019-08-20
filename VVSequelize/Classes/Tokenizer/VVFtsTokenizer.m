//
//  VVFtsTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/4/1.
//

#import "VVFtsTokenizer.h"

@implementation VVFtsToken

+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end
{
    VVFtsToken *tk = [VVFtsToken new];
    tk.token = token;
    tk.start = start;
    tk.len = len;
    tk.end = end;
    return tk;
}

- (NSString *)description {
    return _token;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"'%@',%@,%@,%@", _token, @(_len), @(_start), @(_end)];
}

@end
