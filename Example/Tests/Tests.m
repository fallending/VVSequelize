//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import "MJExtension.h"
#import "YYModel.h"
#import <VVSequelize/VVSequelize.h>
#import <VVSequelize/VVClassInfo.h>
#import <CoreLocation/CoreLocation.h>

@import XCTest;

@interface Tests : XCTestCase
@property (nonatomic, strong) VVDataBase *vvdb;
@property (nonatomic, strong) VVOrmModel *mobileModel;
@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    
    VVSequelize.loglevel = 2;
#if 0
    [VVSequelize setKeyValuesToObject:^id(Class cls, NSDictionary *dic) {
        return [cls mj_objectWithKeyValues:dic];
    }];
    [VVSequelize setKeyValuesArrayToObjects:^NSArray *(Class cls, NSArray *dicArray) {
        return [cls mj_objectArrayWithKeyValuesArray:dicArray];
    }];
    [VVSequelize setObjectToKeyValues:^id(Class cls, id object) {
        return [object mj_keyValues];
    }];
    [VVSequelize setObjectsToKeyValuesArray:^NSArray *(Class cls, NSArray *objects) {
        return [cls mj_keyValuesArrayWithObjectArray:objects];
    }];
#else
    [VVSequelize useVVKeyValue];
#endif
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *targetPath = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:targetPath]){
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"mobiles.sqlite" ofType:nil];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:nil];
    }

    self.vvdb = [[VVDataBase alloc] initWithDBName:@"mobiles.sqlite" dirPath:nil encryptKey:nil];
    VVOrmSchemaItem *column1 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"mobile",@"pk":@(YES)}];
//    VVOrmSchemaItem *column2 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"times",@"unique":@(YES)}];
    self.mobileModel = [VVOrmModel ormModelWithClass:VVTestMobile.class
                                             manuals:@[column1]
                                            excludes:nil
                                           tableName:@"mobiles"
                                            dataBase:self.vvdb
                                              logAt:YES];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFind{
    NSArray *array = [self.mobileModel findAll:nil fields:@[@"mobile",@"city"] orderBy:nil range:NSMakeRange(0, 10)];
    NSLog(@"array:%@",array);
    array = [self.mobileModel findAll:nil fields:nil orderBy:nil range:NSMakeRange(0, 10)];
    NSLog(@"array:%@",array);
    array = [self.mobileModel findAll:nil fields:@[@"",@""] orderBy:nil range:NSMakeRange(0, 10)];
    NSLog(@"array:%@",array);
    array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
    NSLog(@"array:%@",array);
    id obj = [self.mobileModel findOne:nil];
    NSLog(@"obj:%@",obj);
}

- (void)testInQueue{
    id obj = [self.mobileModel.vvdb inQueue:^id{
        return [self.mobileModel findAll:nil fields:nil orderBy:nil range:NSMakeRange(0, 100)];
    }];
    NSLog(@"obj:%@",obj);
}

- (void)testInTransaction{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger i = 0; i < 100; i ++) {
        VVTestMobile *mobile = [VVTestMobile new];
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i",arc4random_uniform(99),arc4random_uniform(9999),arc4random_uniform(9999)];
        mobile.province = @"四川";
        mobile.city = @"成都";
        mobile.industry = @"IT";
        mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
        [array addObject:mobile];
    }

    id obj = [self.mobileModel.vvdb inTransaction:^id(BOOL *rollback) {
        for (VVTestMobile *m in array) {
            BOOL ret = [self.mobileModel insertOne:m];
            if(!ret){
                *rollback = YES;
            }
        }
        return @(YES);
    }];
    NSLog(@"obj:%@",obj);
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
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i",arc4random_uniform(99),arc4random_uniform(9999),arc4random_uniform(9999)];
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
        mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i",arc4random_uniform(99),arc4random_uniform(9999),arc4random_uniform(9999)];
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

- (void)testMaxMinSum{
    id max = [self.mobileModel max:@"relative"];
    id min = [self.mobileModel min:@"relative"];
    id sum = [self.mobileModel sum:@"relative"];
    NSLog(@"max : %@, min : %@, sum : %@", max, min, sum);
}


- (void)testOrmModel{
//    VVOrmModel *personModel = [[VVOrmModel alloc] initWithClass:VVTestPerson.class];
    VVOrmSchemaItem *column1 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"idcard",@"pk":@(YES)}];
    VVOrmSchemaItem *column2 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"mobile",@"unique":@(YES)}];
    VVOrmSchemaItem *column3 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"name",@"notnull":@(YES)}];
    VVOrmSchemaItem *column4 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"arr",@"unique":@(YES),@"notnull":@(YES)}];

    VVOrmModel *personModel1 = [VVOrmModel ormModelWithClass:VVTestPerson.class
                                                     manuals:@[column1,column2,column3,column4]
                                                    excludes:nil
                                                   tableName:@"persons"
                                                    dataBase:nil
                                                      logAt:YES];
    NSUInteger maxrowid = [personModel1 maxRowid];
//    NSLog(@"%@", personModel);
    NSLog(@"maxrowid: %@", @(maxrowid));
    NSString *sql = @"UPDATE \"persons\" SET \"name\" = \"lisi\" WHERE \"idcard\" = \"123456\"";
    VVDataBase *vvdb = [personModel1 valueForKey:@"vvdb"];
    BOOL ret = [vvdb executeUpdate:sql];
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
    NSDate *now = [NSDate date];
    VVTestPerson *person = [VVTestPerson new];
    person.idcard = @"123123";
    person.name = @"zhangsan";
    person.age = 19;
    person.birth = now;
    person.mobile = @"123123123";
    NSDictionary *dic = person.vv_keyValues;
    NSLog(@"%@",dic);
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

- (void)testObjEmbed{
    NSDate *now = [NSDate date];
    VVTestPerson *person = [VVTestPerson new];
    person.idcard = @"123123";
    person.name = @"zhangsan";
    person.age = 19;
    person.birth = now;
    person.mobile = @"123123123";
    VVTestMobile *mobile = [VVTestMobile new];
    mobile.mobile = [NSString stringWithFormat:@"1%02i%04i%04i",arc4random_uniform(99),arc4random_uniform(9999),arc4random_uniform(9999)];
    mobile.province = @"四川";
    mobile.city = @"成都";
    mobile.industry = @"IT";
    mobile.relative = arc4random_uniform(100) * 1.0 / 100.0;
    VVTestOne *one = [VVTestOne new];
    one.oneId = 1;
    one.person = person;
    one.mobiles = @[mobile];
    one.friends = [NSSet setWithArray:@[person]];
    one.flag = @"hahaha";
    one.dic = @{@"a":@(1),@"b":@(2)};
    one.arr = @[@(1),@(2),@(3)];
    
    NSDictionary *oneDic = one.vv_keyValues;
    NSLog(@"dic: %@",oneDic);
    VVTestOne *nOne = [VVTestOne vv_objectWithKeyValues:oneDic];
    NSLog(@"obj: %@",nOne);
    VVOrmModel *orm = [VVOrmModel ormModelWithClass:VVTestOne.class primaryKey:@"oneId"];
    [orm upsertOne:one];
    VVTestOne *mOne = [orm findOne:nil];
    NSLog(@"mOne: %@",mOne);
}


- (void)testMixDataTypes{
    VVTestMix *mix = [VVTestMix new];
    mix.num = @(10);
    mix.cnum = 9;
    mix.val = [NSValue valueWithRange:NSMakeRange(0, 20)];
    mix.decNum = [NSDecimalNumber decimalNumberWithString:@"2.53"];
    mix.size = CGSizeMake(90, 30);
    mix.point = CGPointMake(5, 75);
    VVTestUnion un;
    un.num = 65535;
    mix.un =  un;
    VVTestStruct stru;
    stru.ch = 'x';
    stru.num = 8;
    mix.stru = stru;
    NSString *temp = @"hahaha";
    char *str = (char *)[temp UTF8String];
    mix.str = str;
    mix.sa = 'b';
    mix.unknown = (void *)str;
    mix.selector = NSSelectorFromString(@"help:");
    NSDictionary *mixkvs = mix.vv_keyValues;
    NSLog(@"mix: %@", mixkvs);
    VVTestMix *mix2 = [VVTestMix vv_objectWithKeyValues:mixkvs];
    NSLog(@"mix2: %@",mix2);
    VVOrmModel *orm = [VVOrmModel ormModelWithClass:VVTestMix.class primaryKey:@"num"];
    [orm upsertOne:mix];
    VVTestMix *mix3 = [orm findOne:nil];
    NSLog(@"mix3: %@",mix3);

}

- (void)testUnion{
    VVTestUnion un;
    un.ch = 3;
    NSValue *value = [NSValue valueWithBytes:&un objCType:@encode(VVTestUnion)];
    VVTestUnion ne;
    [value getValue:&ne];
    NSLog(@"value: %@",value);
    CLLocationCoordinate2D coordinate2D = CLLocationCoordinate2DMake(30.546887, 104.064271);
    NSValue *value1 = [NSValue valueWithCoordinate2D:coordinate2D];
    CLLocationCoordinate2D coordinate2D1 = value1.coordinate2DValue;
    NSString *string = NSStringFromCoordinate2D(coordinate2D);
    CLLocationCoordinate2D coordinate2D2 = Coordinate2DFromString(@"{adads3.0,n5.2vn}");

    NSLog(@"string: %@, coordinate2D1: {%f,%f}, coordinate2D2: {%f,%f}",string,coordinate2D1.latitude,coordinate2D1.longitude,coordinate2D2.latitude,coordinate2D2.longitude);
}

- (void)testColletionDescription{
    NSArray *array1 = @[@(1),@(2),@(3)];
    NSArray *array2 = @[@"1",@"2",@"3",array1];
    NSDictionary *dic3 = @{@"a":@(1),@"b":@(2),@"c":@(3)};
    NSSet *set4 = [NSSet setWithArray:array1];
    NSString *string5 = @"hahaha";
    id val1 = [array1 vv_dbStoreValue];
    id val2 = [array2 vv_dbStoreValue];
    id val3 = [dic3 vv_dbStoreValue];
    id val4 = [set4 vv_dbStoreValue];
    id val5 = [string5 vv_dbStoreValue];
    NSLog(@"%@",val1);
}
@end

