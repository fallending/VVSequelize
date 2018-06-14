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
#import "VVSequelize.h"
#import "MJExtension.h"

@import XCTest;

@interface Tests : XCTestCase
@property (nonatomic, strong) VVFMDB *vvfmdb;
@property (nonatomic, strong) VVOrmModel *mobileModel;
@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    VVSequelizeConst.verbose = YES;
    [VVSequelize setDicToObject:^id(Class cls, NSDictionary *dic) {
        return [cls mj_objectWithKeyValues:dic];
    }];
    [VVSequelize setDicArrayToObjects:^NSArray *(Class cls, NSArray *dicArray) {
        return [cls mj_objectArrayWithKeyValuesArray:dicArray];
    }];
    [VVSequelize setObjectToDic:^id(Class cls, id object) {
        return [object mj_keyValues];
    }];
    [VVSequelize setObjectsToDicArray:^NSArray *(Class cls, NSArray *objects) {
        return [cls mj_keyValuesArrayWithObjectArray:objects];
    }];
    
    NSString *path = [[NSBundle mainBundle] bundlePath];
    self.vvfmdb = [[VVFMDB alloc] initWithDBName:@"mobiles.sqlite" dirPath:path encryptKey:nil];
    self.mobileModel = [[VVOrmModel alloc] initWithClass:VVTestMobile.class
                                            fieldOptions:@{@"mobile":@(VVOrmPrimaryKey)}
                                                excludes:nil
                                               tableName:@"mobiles"
                                                dataBase:self.vvfmdb];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMobileModel{
    NSInteger count = [self.mobileModel count:nil];
    BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
    NSLog(@"count: %@", @(count));
    NSLog(@"array: %@", array);
    NSLog(@"ret: %@", @(ret));
}

- (void)testCreate{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i ++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%4i%4i",arc4random_uniform(9999),arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }
    BOOL ret = [self.mobileModel insertOne:array[0]];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel insertMulti:array];
    NSLog(@"ret: %@", @(ret));
}

- (void)testUpdate{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i ++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%4i%4i",arc4random_uniform(9999),arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }
    VVTestMobile *mobile = [self.mobileModel findOne:nil];
    mobile.province = @"四川";
    mobile.city = @"成都";
    mobile.industry = @"IT";
    BOOL ret = [self.mobileModel updateOne:mobile];
    NSLog(@"ret: %@", @(ret));
    NSArray *objects = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(1, 9)];
    for (VVTestMobile *m in objects) {
        m.province = @"四川";
        m.city = @"成都";
        m.industry = @"IT";
    }
    ret = [self.mobileModel updateMulti:objects];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel upsertOne:array[0]];
    NSLog(@"ret: %@", @(ret));
    ret = [self.mobileModel upsertMulti:array];
    NSLog(@"ret: %@", @(ret));
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

- (void)testExample
{
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

