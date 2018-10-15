# VVSequelize

[![Version](https://img.shields.io/cocoapods/v/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![License](https://img.shields.io/cocoapods/l/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![Platform](https://img.shields.io/cocoapods/p/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)

## 功能
* [x] 根据Class生成数据表
* [x] 增删改查,insert,update,upsert,delele,drop...
* [x] Where语句生成,可满足大部分常规场景
* [x] 数据库加解密(SQLCipher)
* [x] 原生SQL语句支持
* [x] 常规查询支持,max,min,sum,count...
* [x] 主键支持(可自动主键),唯一性约束支持.
* [x] Transaction支持
* [x] Object直接处理
* [x] 数据存储,OC类型支持: NSData, NSURL, NSSelector, NSValue, NSDate, NSArray, NSDictionary, NSSet,...
* [x] 数据存储,C类型支持: char *, struct, union
* [x] 子对象存储为Json字符串
* [x] OrmModel查询缓存
* [x] FTS全文搜索

## 改动(0.3.0-beta2)
1. 可创建内存数据库,未测试
2. 添加通用的版本升级辅助类`VVUpgrader`

## 安装
使用测试版本:
```ruby
    pod 'VVSequelize', :git => 'https://github.com/pozi119/VVSequelize.git'
```
使用稳定版本:
```ruby
    pod 'VVSequelize', '0.2.1'
```
## 注意
1. 子对象会保存成为Json字符串,子对象内的NSData也会保存为16进制字符串.
2. 含有子对象时,请确保不会循环引用,否则`Dictionary/Object`互转会死循环,请将相应的循环引用加入互转黑名单. 
3. VVKeyValue仅用于本工具,不适用常规的Json转对象.

## 用法
此处主要列出一些基本用法,详细用法请阅读代码注释.

### 全局配置
sqlite3封装类请参考`VVSequelize_Tests`中`VVTestDBClass`的实现方式.
```objc
    // 必须设置sqlite3封装类
    [VVSequelize setDbClass:VVTestDBClass.class];
    
    [VVSequelize setTrace:^(NSString *sql, NSArray *values, id results, NSError *error) { 
        //加入对每个sql执行情况的跟踪
    }];
```

### 打开/创建数据库文件
```objc
    self.vvdb = [[VVDataBase alloc] initWithDBName:@"mobiles.sqlite"];
```

### 定义ORM配置
使用`VVOrmConfig`统一表配置,方便复用,支持链式赋值.
```objc
    VVOrmConfig *config = [[VVOrmConfig configWithClass:VVTestMobile.class] primaryKey:@"mobile"];
``` 

### 定义ORM模型 
可自定义表名和存放的数据库文件.
生成的模型将不在保存在ModelPool中,防止表过多导致内存占用大,需要请自行实现.

示例如下:

```objc
    self.mobileModel = [VVOrm ormModelWithConfig:config tableName:@"mobiles" dataBase:self.vvdb];
```
### 增删改查
使用ORM模型进行增删改查等操作.

示例如下:

```objc
NSInteger count = [self.mobileModel count:nil];
BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
NSArray *array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
...
```

### 生成SQL子句
现在仅支持非套嵌的字典或字典数组,转换方式如下:
```
//where/having :
{field1:val1,field2:val2} --> field1 = "val1" AND field2 = "val2"
[{field1:val1,field2:val2},{field3:val3}] --> (field1 = "val1" AND field2 = "val2") OR (field3 = "val3")
//group by:
[filed1,field2] --> "field1","field2"
//order by
[filed1,field2] --> "field1","field2" ASC
[filed1,field2].desc --> "field1","field2" DESC
```
示例: 
```objc
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
```

## Author

Valo Lee, pozi119@163.com

## License

VVSequelize is available under the MIT license. See the LICENSE file for more info.
