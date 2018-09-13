//
//  VVOrmField.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmField.h"

@implementation VVOrmField

+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary{
    return nil;  // 由子类实现
}

- (BOOL)isEqualToField:(VVOrmField *)field{
    return NO;   // 由子类实现
}

@end
