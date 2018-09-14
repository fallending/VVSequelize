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

## 开发中(0.3.0)
* [ ] FTS全文搜索
* [ ] 重写sql语句生成

## 改动(0.3.0-beta0)
1. 去除FMDB关联,仅提供SQL语句生成
2. 索引支持,尚未测试...
3. FTS创建表,尚未测试...

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
    self.mobileModel = [VVOrmModel ormModelWithConfig:config tableName:@"mobiles" dataBase:self.vvdb];
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

### 生成Where语句
采用了类似sequelize.js的方式生成where语句.具体说明请参考```VVSqlGenerator.h```中的注释.

示例如下:

```objc
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
```

## Author

Valo Lee, pozi119@163.com

## License

VVSequelize is available under the MIT license. See the LICENSE file for more info.
