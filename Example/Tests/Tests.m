//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo Lee on 06/06/2018.
//  Copyright (c) 2018 Valo Lee. All rights reserved.
//

#import "VVTestClasses.h"
#import <VVSequelize/VVSequelize.h>
#import <CoreLocation/CoreLocation.h>

@import XCTest;

@interface Tests : XCTestCase
@property (nonatomic, strong) VVDatabase *vvdb;
@property (nonatomic, strong) VVOrm *mobileModel;
@property (nonatomic, strong) VVOrm *ftsModel;
@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *targetPath = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:targetPath]){
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"mobiles.sqlite" ofType:nil];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:nil];
    }
    
    NSString *vvdb = [path stringByAppendingPathComponent:@"mobiles.sqlite"];
    self.vvdb = [[VVDatabase alloc] initWithPath:vvdb];
    
    NSString *dbpath = [path stringByAppendingPathComponent:@"test1.sqlite"];

    @autoreleasepool {
        VVDatabase *db1 = [[VVDatabase alloc] initWithPath:dbpath];
//        db1 = nil;
        VVDatabase *db2 = [[VVDatabase alloc] initWithPath:dbpath];
//        db2 = nil;
        VVDatabase *db3 = [[VVDatabase alloc] initWithPath:dbpath];
        if(db1 && db2 && db3) {}
    }
    
    [self.vvdb registerFtsFiveTokenizer:VVFtsJiebaTokenizer.class forName:@"jieba"];
    
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestMobile.class];
    config.primaries = @[@"mobile"];
    self.mobileModel = [VVOrm ormWithConfig:config tableName:@"mobiles" dataBase:self.vvdb];
    VVOrmConfig *ftsConfig = [VVOrmConfig ftsConfigWithClass:VVTestMobile.class module:@"fts5" tokenizer:@"jieba pinyin" indexes: @[@"mobile", @"industry"]];

    self.ftsModel = [VVOrm ormWithConfig:ftsConfig tableName:@"fts_mobiles" dataBase:self.vvdb];
    //复制数据到fts表
    NSUInteger count = [self.ftsModel count:nil];
    if(count == 0){
        [self.vvdb excute:@"INSERT INTO fts_mobiles (mobile, province, city, carrier, industry, relative, times) SELECT mobile, province, city, carrier, industry, relative, times FROM mobiles"];
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//MARK: - 普通表
- (void)testFind{
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil limit:10 offset:0];
    array = [self.mobileModel findAll:nil orderBy:@[@"mobile",@"city"].desc limit:10 offset:0];
    array = [self.mobileModel findAll:@"mobile > 15000000000" orderBy:@"mobile ASC,city DESC" limit:5 offset:0];
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
    BOOL ret = [self.mobileModel insertMulti:array];
    NSLog(@"ret: %@",@(ret));
}

- (void)testMobileModel{
    NSInteger count = [self.mobileModel count:nil];
    BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
    NSArray *array = [self.mobileModel findAll:nil orderBy:nil limit:10 offset:0];
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
    NSArray *objects = [self.mobileModel findAll:nil orderBy:nil limit:9 offset:1];
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
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestPerson.class];
    config.primaries = @[@"idcard"];
    config.uniques   = @[@"mobile",@"arr"];
    config.notnulls  = @[@"name",@"arr"];

    VVOrm *personModel1 = [VVOrm ormWithConfig:config tableName:@"persons" dataBase:self.vvdb];
    NSUInteger maxrowid = [personModel1 maxRowid];
//    NSLog(@"%@", personModel);
    NSLog(@"maxrowid: %@", @(maxrowid));
    NSString *sql = @"UPDATE \"persons\" SET \"name\" = \"lisi\" WHERE \"idcard\" = \"123456\"";
    VVDatabase *vvdb = personModel1.vvdb;
    BOOL ret = [vvdb excute:sql];
    NSLog(@"%@",@(ret));
}

- (void)testClause{
    VVSelect *select =  [VVSelect new];
    select.table(@"mobiles");
    select.where(@"relative".lt(@(0.3)).and(@"mobile".gte(@(1600000000))).and(@"times".gte(@(0))));
    NSLog(@"%@", select.sql);
    select.where(@{@"city":@"西安", @"relative":@(0.3)});
    NSLog(@"%@", select.sql);
    select.where(@[@{@"city":@"西安", @"relative":@(0.3)},@{@"relative":@(0.7)}]);
    NSLog(@"%@", select.sql);
    select.where(@"relative".lt(@(0.3)));
    NSLog(@"%@", select.sql);
    select.where(@"     where relative < 0.3");
    NSLog(@"%@", select.sql);
    select.groupBy(@"city");
    NSLog(@"%@", select.sql);
    select.groupBy(@[@"city",@"carrier"]);
    NSLog(@"%@", select.sql);
    select.groupBy(@" group by city carrier");
    NSLog(@"%@", select.sql);
    select.having(@"relative".lt(@(0.2)));
    NSLog(@"%@", select.sql);
    select.groupBy(nil);
    NSLog(@"%@", select.sql);
    select.orderBy(@[@"city",@"carrier"]);
    NSLog(@"%@", select.sql);
    select.orderBy(@" order by relative");
    NSLog(@"%@", select.sql);
    select.limit(10);
    NSLog(@"%@", select.sql);
    select.distinct(YES);
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
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestOne.class];
    config.primaries = @[@"oneId"];
    VVOrm *orm = [VVOrm ormWithConfig:config];
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
    VVOrmConfig *config = [VVOrmConfig configWithClass:VVTestMix.class];
    config.primaries = @[@"num"];
    VVOrm *orm = [VVOrm ormWithConfig:config];
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
    VVDBUpgrader *upgrader = [[VVDBUpgrader alloc] init];
    upgrader.versions = @[@"0.1.0",@"0.1.1",@"0.1.3",@"0.1.5"];
    upgrader.upgrades[@"0.1.1"] = ^(NSProgress *progress){
        NSLog(@"update-> 0.1.1");
        for (NSInteger i = 0; i < 100; i ++) {
            progress.completedUnitCount = ((i + 1) * progress.totalUnitCount) / 100;
        }
    };
    upgrader.upgrades[@"0.1.2"] = ^(NSProgress *progress){
        NSLog(@"update-> 0.1.2");
        for (NSInteger i = 0; i < 100; i ++) {
            progress.completedUnitCount = ((i + 1) * progress.totalUnitCount) / 100;
        }
    };
    upgrader.upgrades[@"0.1.3"] = ^(NSProgress *progress){
        NSLog(@"update-> 0.1.3");
//        for (NSInteger i = 0; i < 100; i ++) {
//            progress.completedUnitCount = ((i + 1) * progress.totalUnitCount) / 100;
//        }
    };
    upgrader.upgrades[@"0.1.4"] = ^(NSProgress *progress){
        NSLog(@"update-> 0.1.4");
        for (NSInteger i = 0; i < 100; i ++) {
            progress.completedUnitCount = ((i + 1) * progress.totalUnitCount) / 100;
        }
    };
    upgrader.upgrades[@"0.1.5"] = ^(NSProgress *progress){
        NSLog(@"update-> 0.1.5");
//        for (NSInteger i = 0; i < 100; i ++) {
//            progress.completedUnitCount = ((i + 1) * progress.totalUnitCount) / 100;
//        }
    };
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];
    [progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:nil];
    [upgrader upgradeFrom:@"0.1.2" progress:progress];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    NSProgress *progress = object;
    NSLog(@"progress: %@",@(progress.fractionCompleted));
}

//MARK: - FTS表
- (void)testMatch{
    NSString *keyword = @"180*";
    NSArray *array1 = [self.ftsModel match:@{@"mobile":keyword} orderBy:nil limit:0 offset:0];
    NSArray *array2 = [self.ftsModel match:@{@"mobile":keyword} groupBy:nil limit:0 offset:0];
    NSUInteger count = [self.ftsModel matchCount:@{@"mobile":keyword}];
    NSArray *highlighted = [self.ftsModel highlight:array1 field:@"mobile" keyword:keyword attributes:@{NSForegroundColorAttributeName:[UIColor redColor]}];
    if(array1 && array2 && count && highlighted){}
}
@end

