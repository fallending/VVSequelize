//
//  VVTestClasses.m
//  VVSequelize_Tests
//
//  Created by Jinbo Li on 2018/6/12.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import "MJExtension.h"
#import <VVSequelize/VVSequelize.h>

@implementation VVTestMobile

@end

@implementation VVTestPerson

@end

@implementation VVTestOne

+ (NSDictionary *)mj_objectClassInArray{
    return @{@"mobiles":VVTestMobile.class,@"friends":@"VVTestPerson"};
}

+ (nullable NSArray<NSString *> *)vv_ignoreProperties{
    return @[@"dic"];
}


@end

@implementation VVTestMix

@end
