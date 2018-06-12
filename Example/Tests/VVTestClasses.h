//
//  VVTestClasses.h
//  VVSequelize_Tests
//
//  Created by Jinbo Li on 2018/6/12.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VVTestPerson : NSObject
@property (nonatomic, copy  ) NSString *idcard;
@property (nonatomic, copy  ) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) NSDate *birth;
@property (nonatomic, copy  ) NSString *mobile;

/*
@property (nonatomic, assign) BOOL male;
@property (nonatomic, strong) NSDictionary *dic;
@property (nonatomic, strong) NSMutableSet *mdic;
@property (nonatomic, strong) NSArray *arr;
@property (nonatomic, strong) NSMutableArray *marr;
@property (nonatomic, copy  ) NSMutableString *mstr;
@property (nonatomic, strong) NSSet *set;
@property (nonatomic, strong) NSMutableSet *mset;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSMutableData *mdata;
*/

@end
