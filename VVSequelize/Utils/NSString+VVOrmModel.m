//
//  NSString+VVOrmModel.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "NSString+VVOrmModel.h"

@implementation NSString (VVOrmModel)

- (NSString *)trim{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)isMatchRegex:(NSString *)regex{
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    NSRange range = [self rangeOfString:regex options:options];
    return range.location != NSNotFound;
}

- (NSString *)prepareForParseSQL{
    NSString *tmp = [self stringByReplacingOccurrencesOfString:@" +" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
    tmp = [tmp stringByReplacingOccurrencesOfString:@"'|\"" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, tmp.length)];
    return tmp.trim;
}

@end
