//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVOrmModel.h"
#import "VVTestClasses.h"
#import "VVSequelizeConst.h"
#import "VVSqlGenerator.h"

@import XCTest;

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    VVSequelizeConst.verbose = YES;
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOrmModel{
//    VVOrmModel *personModel = [[VVOrmModel alloc] initWithClass:VVTestPerson.class];
    VVOrmModel *personModel1 = [[VVOrmModel alloc] initWithClass:VVTestPerson.class
                                                    fieldOptions:@{@"idcard":@(VVOrmPrimaryKey),
                                                                   @"mobile":@(VVOrmUnique),
                                                                   @"name":@(VVOrmNonnull),
                                                                   @"arr":@(VVOrmUnique | VVOrmNonnull)}
                                                        excludes:nil
                                                       tableName:@"persons"
                                                        dataBase:nil];    
//    NSLog(@"%@", personModel);
    NSLog(@"%@", personModel1);
    NSString *sql = @"UPDATE \"persons\" SET \"name\" = \"lisi\" WHERE \"idcard\" = \"123456\"";
    VVFMDB *vvfmdb = [personModel1 valueForKey:@"vvfmdb"];
    BOOL ret = [vvfmdb.db executeQuery:sql];
    NSLog(@"%@",@(ret));

}

- (void)testWhere{
    NSArray *conditions = @[
                            @{@"name":@"zhangsan", @"age":@(26)},
                            @{@"$or":@[@{@"name":@"zhangsan",@"age":@(26)},@{@"age":@(30)}]},
                            @{@"age":@{@"$lt":@(30)}},
                            @{@"$or":@[@{@"name":@"zhangsan"},@{@"age":@{@"$lt":@(30)}}]},
                            @{@"type":@{@"$in":@[@"a",@"b",@"c"]}},
                            @{@"score":@{@"$between":@[@"20",@"40"]}},
                            @{@"text":@{@"$like":@"%%haha"}},
                            @{@"score":@{@"$gt":@(60),@"$lte":@(80)}},
                            @{@"age":@{@"$or":@[
                                      @{@"age":@{@"$gt":@(10)}},
                                      @{@"age":@{@"$lte":@(30)}}
                                      ]},
                              @"name":@{@"$notLike":@"%%zhangsan"},
                              @"$or":@[@{@"score":@{@"$gt":@(60),@"$lte":@(80)}},@{@"score":@{@"$gt":@(20),@"$lte":@(40)}}]
                              }
                            ];
    for (NSDictionary *condition in conditions) {
        NSString *where = [VVSqlGenerator where:condition];
        NSLog(@"where sentence : %@", where);
    }
}

- (void)testUpdate{
}

- (void)testExample
{
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

