//
//  VVTestClasses.m
//  VVSequelize_Tests
//
//  Created by Jinbo Li on 2018/6/12.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import "MJExtension.h"

@implementation VVTestMobile

@end

@implementation VVTestPerson

//+ (NSMutableArray *)mj_totalIgnoredPropertyNames{
//    return @[@"birth"].mutableCopy;
//}

- (id)mj_newValueFromOldValue:(id)oldValue property:(MJProperty *)property{
    if([property.name isEqualToString:@"birth"]){
        if (oldValue && [oldValue isKindOfClass:[NSDate class]]) {
            NSDate *date = oldValue;
            return @([date timeIntervalSince1970]);
        }
        return @(0);
    }
    return oldValue;
}

@end
