//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVOrmModel.h"
#import "VVTestClasses.h"

@import XCTest;

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOrmModel{
    VVOrmModel *personModel = [[VVOrmModel alloc] initWithClass:VVTestPerson.class];
    VVOrmModel *personModel1 = [[VVOrmModel alloc] initWithClass:VVTestPerson.class
                                                    fieldOptions:@{@"idcard":@(VVOrmPrimaryKey),
                                                                   @"mobile":@(VVOrmUnique),
                                                                   @"name":@(VVOrmNonnull)}
                                                        excludes:nil
                                                       tableName:@"persons"
                                                        dataBase:nil];
    NSLog(@"%@", personModel);
    NSLog(@"%@", personModel1);
}

- (void)testExample
{
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

