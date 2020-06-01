//
//  VVTestClasses.m
//  VVSequelize_Tests
//
//  Created by Valo on 2018/6/12.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import <VVSequelize/VVSequelize.h>

@implementation VVTestMobile

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ | %@ | %@ | %@ | %@ | %2.f | %@", _mobile, _province, _city, _carrier, _industry, _relative, @(_times)];
}

@end

@implementation VVTestPerson

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ | %@ | %@ | %@ | %@", _name, _idcard, @(_age), _birth, _mobile];
}

@end

@implementation VVTestOne

+ (NSDictionary *)mj_objectClassInArray
{
    return @{ @"mobiles": VVTestMobile.class, @"friends": @"VVTestPerson" };
}

+ (nullable NSArray<NSString *> *)vv_ignoreProperties
{
    return @[@"dic"];
}

@end

@implementation VVTestMix

@end

@implementation VVTestEnumerator
+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    NSUInteger count = input.length;
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        const char *prefix = [input substringToIndex:i].cLangString;
        NSString *cur = [input substringWithRange:NSMakeRange(i, 1)];
        int start = (int)strlen(prefix);
        int len = (int)strlen(cur.cLangString);
        VVToken *token = [VVToken token:cur len:len start:start end:(start + len)];
        [results addObject:token];
    }
    return results;
}

@end
