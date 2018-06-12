//
//  VVTestClasses.h
//  VVSequelize_Tests
//
//  Created by Jinbo Li on 2018/6/12.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VVTestPerson : NSObject
@property (nonatomic, copy) NSString *idcard;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) NSDate *birth;
@property (nonatomic, copy) NSString *mobile;
@end
