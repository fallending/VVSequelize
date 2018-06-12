//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVOrmModel.h"

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

- (void)testOrmOptions{
    NSDictionary *xdic = nil;
    NSDictionary *dic = @{@"key1": @(1), @"key2":@(2)};
    NSUInteger i = [xdic[@"a"] integerValue];
    for (NSString *key in dic) {
        NSNumber *val = dic[key];
        NSLog(@"key : %@, val: %@", key,val);
    }
}

- (void)testExample
{
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

