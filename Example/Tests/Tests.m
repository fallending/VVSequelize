//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import "VVTestDBClass.h"
#import <VVSequelize/VVSequelize.h>
#import <CoreLocation/CoreLocation.h>

@import XCTest;

@interface Tests : XCTestCase
@property (nonatomic, strong) VVDataBase *vvdb;
@property (nonatomic, strong) VVOrm *mobileModel;
@property (nonatomic, strong) VVOrm *ftsModel;
@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    [VVSequelize setDbClass:VVTestDBClass.class];
    [VVSequelize setTrace:^(NSString *sql, NSArray *values, id results, NSError *error) {
        NSLog(@"\n----------VVSequelize----------\n"
              "sql    : %@\n"
              "values : %@\n"
              "results: %@\n"
              "error  : %@\n"
              @"-------------------------------\n",
              sql, values, results, error);
    }];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *targetPath = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:targetPath]){
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"mobiles.sqlite" ofType:nil];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:nil];
    }
    
    NSString *vvdb = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    self.vvdb = [[VVDataBase alloc] initWithPath:vvdb];
    
    NSString *dbp = [path stringByAppendingPathComponent:@"test1.sqlite"];

    @autoreleasepool {
        VVDataBase *db1 = [[VVDataBase alloc] initWithPath:dbp];
//        db1 = nil;
        VVDataBase *db2 = [[VVDataBase alloc] initWithPath:dbp];
//        db2 = nil;
        VVDataBase *db3 = [[VVDataBase alloc] initWithPath:dbp];
        if(db1 && db2 && db3) {}
    }
    
    VVOrmConfig *config = [[VVOrmConfig configWithClass:VVTestMobile.class] primaryKey:@"mobile"];
    self.mobileModel = [VVOrm ormModelWithConfig:config tableName:@"mobiles" dataBase:self.vvdb];
    VVOrmConfig *ftsConfig = [[[VVOrmConfig configWithClass:VVTestMobile.class] ftsModule:@"fts4"] fts:YES];
    self.ftsModel = [VVOrm ormModelWithConfig:ftsConfig tableName:@"fts_mobiles" dataBase:self.vvdb];
    //复制数据到fts表
    NSUInteger count = [self.ftsModel count:nil];
    if(count == 0){
        [self.vvdb executeUpdate:@"INSERT INTO fts_mobiles (mobile, province, city, carrier, industry, relative, times) SELECT mobile, province, city, carrier, industry, relative, times FROM mobiles"];
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//MARK: - 普通表
- (void)testFind{
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
    array = [self.mobileModel findAll:nil orderBy:@[@"mobile",@"city"].desc range:NSMakeRange(0, 10)];
    array = [self.mobileModel findAll:@"mobile > 15000000000" orderBy:@"mobile ASC,city DESC" range:NSMakeRange(0, 5)];
    id obj = [self.mobileModel findOne:nil orderBy:@"mobile DESC,city ASC"];
    if(array && obj) {}
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
    VVDataBase *vvdb = self.mobileModel.vvdb;
    BOOL ret = [vvdb beginTransaction];
    if(ret) {
        ret = [self.mobileModel insertMulti:array];
    }
    if(ret) {
        [vvdb commit];
    }else{
        [vvdb rollback];
    }
    NSLog(@"ret: %@",@(ret));
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
    id max = [self.mobileModel max:@"relative" condition:nil];
    id min = [self.mobileModel min:@"relative" condition:nil];
    id sum = [self.mobileModel sum:@"relative" condition:nil];
    NSLog(@"max : %@, min : %@, sum : %@", max, min, sum);
}

- (void)testOrmModel{
//    VVOrmModel *personModel = [[VVOrmModel alloc] initWithClass:VVTestPerson.class];
    VVOrmField *field1 = VVFIELD_PK(@"idcard");;
    VVOrmField *field2 = VVFIELD_UNIQUE(@"mobile");
    VVOrmField *field3 = VVFIELD_NOTNULL(@"name");
    VVOrmField *field4 = VVFIELD_UNIQUE_NOTNULL(@"arr");
    VVOrmConfig *config = [[VVOrmConfig configWithClass:VVTestPerson.class] manuals:@[field1,field2,field3,field4]];

    VVOrm *personModel1 = [VVOrm ormModelWithConfig:config tableName:@"persons" dataBase:nil];
    NSUInteger maxrowid = [personModel1 maxRowid];
//    NSLog(@"%@", personModel);
    NSLog(@"maxrowid: %@", @(maxrowid));
    NSString *sql = @"UPDATE \"persons\" SET \"name\" = \"lisi\" WHERE \"idcard\" = \"123456\"";
    VVDataBase *vvdb = [personModel1 valueForKey:@"vvdb"];
    BOOL ret = [vvdb executeUpdate:sql];
    NSLog(@"%@",@(ret));
}

- (void)testClause{
    VVSelect *select = [[VVSelect prepare] table:@"mobiles"];
    [select where:[[[@"relative" lt:@(0.3)] and:[@"mobile" gte:@(16000000000)]] and: [@"times" gte:@(0)]]];
    NSLog(@"%@", select.sql);
    [select where:@{@"city":@"西安", @"relative":@(0.3)}];
    NSLog(@"%@", select.sql);
    [select where:@[@{@"city":@"西安", @"relative":@(0.3)},@{@"relative":@(0.7)}]];
    NSLog(@"%@", select.sql);
    [select where:[@"relative" lt:@(0.3)]];
    NSLog(@"%@", select.sql);
    [select where:@"     where relative < 0.3"];
    NSLog(@"%@", select.sql);
    [select groupBy:@"city"];
    NSLog(@"%@", select.sql);
    [select groupBy:@[@"city",@"carrier"]];
    NSLog(@"%@", select.sql);
    [select groupBy:@" group by city carrier"];
    NSLog(@"%@", select.sql);
    [select having:[@"relative" lt:@(0.2)]];
    NSLog(@"%@", select.sql);
    [select groupBy:nil];
    NSLog(@"%@", select.sql);
    [select orderBy:@[@"city",@"carrier"]];
    NSLog(@"%@", select.sql);
    [select orderBy:@" order by relative"];
    NSLog(@"%@", select.sql);
    [select limit:NSMakeRange(0, 10)];
    NSLog(@"%@", select.sql);
    [select distinct:YES];
    NSLog(@"%@", select.sql);
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
    VVOrmConfig *config = [[VVOrmConfig configWithClass:VVTestOne.class] primaryKey:@"oneId"];
    VVOrm *orm = [VVOrm ormModelWithConfig:config];
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
    VVOrmConfig *config = [[VVOrmConfig configWithClass:VVTestMix.class] primaryKey:@"num"];
    VVOrm *orm = [VVOrm ormModelWithConfig:config];
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
    if(val1 && val2 && val3 && val4 && val5) {}
}

- (void)testUpdateDatabase{
    VVUpgrader *upgrader = [[VVUpgrader alloc] init];
    upgrader.versions = @[@"0.1.0",@"0.1.1",@"0.1.3",@"0.1.5"];
    upgrader.upgrades[@"0.1.1"] = ^{ NSLog(@"update-> 0.1.1"); };
    upgrader.upgrades[@"0.1.2"] = ^{ NSLog(@"update-> 0.1.2"); };
    upgrader.upgrades[@"0.1.3"] = ^{ NSLog(@"update-> 0.1.3"); };
    upgrader.upgrades[@"0.1.4"] = ^{ NSLog(@"update-> 0.1.4"); };
    upgrader.upgrades[@"0.1.5"] = ^{ NSLog(@"update-> 0.1.5"); };
    [upgrader upgradeFrom:@"0.1.2"];
}

//MARK: - FTS表
- (void)testMatch{
    NSString *keyword = @"181*";
    NSArray *array1 = [self.ftsModel match:keyword condition:nil orderBy:@"carrier" range:NSMakeRange(0, 10)];
    NSArray *array2 = [self.ftsModel match:keyword condition:nil groupBy:@"carrier" range:NSMakeRange(0, 10)];
    NSUInteger count = [self.ftsModel matchCount:keyword condition:nil];
    NSString *regex = [VVOrm regularExpressionForKeyword:keyword];
    VVTestMobile *mobile = array1.firstObject;
    NSAttributedString *attrText  = [VVOrm attributedStringWith:mobile.mobile prefix:@"手机:" match:regex attributes:@{NSForegroundColorAttributeName:[UIColor redColor]}];
    if(array1 && array2 && count && attrText){}
}
@end

