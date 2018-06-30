# VVSequelize

[![CI Status](https://img.shields.io/travis/pozi119/VVSequelize.svg?style=flat)](https://travis-ci.org/pozi119/VVSequelize)
[![Version](https://img.shields.io/cocoapods/v/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![License](https://img.shields.io/cocoapods/l/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)
[![Platform](https://img.shields.io/cocoapods/p/VVSequelize.svg?style=flat)](https://cocoapods.org/pods/VVSequelize)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

VVSequelize is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

目前处于开发阶段,不定期更新
```ruby
pod 'VVSequelize', :git => 'https://github.com/pozi119/VVSequelize.git'
```
如果要在Podfile中是使用```use_frameworks!```, 需要在 Podfile 结尾加上hook,为 FMDB 添加头文件搜索路径,解决FMDB编译失败的问题.
```ruby

target 'targetxxxx' do
    pod 'VVSequelize', :git => 'https://github.com/pozi119/VVSequelize.git'
end

post_install do |installer|
    print "Add 'SQLCipher' to FMDB 'HEADER_SEARCH_PATHS' \n"
    installer.pods_project.targets.each do |target|
        if target.name == "FMDB"
            target.build_configurations.each do |config|
                header_search = {"HEADER_SEARCH_PATHS" => "SQLCipher"}
                config.build_settings.merge!(header_search)
            end
        end
    end
end

```

## Usage
1. 设置NSDictionary/NSArray和Object互转. 可不设置, 则某些操作只能支持NSDictionary和NSArray<NSDictionary *>
    设置方法如下:
```objc
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
```

2. 定义ORM模型. 可自定义表名,各字段的参数,不保存的字段, 存放的数据库文件,是否记录创建和更新时间等.  
    生成的模型将使用dbName和tableName生成的字符串作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,这先从模型池中查找.
    示例如下:
```objc
self.vvfmdb = [[VVFMDB alloc] initWithDBName:@"mobiles.sqlite" dirPath:nil encryptKey:nil];
VVOrmSchemaItem *column1 =[VVOrmSchemaItem schemaItemWithDic:@{@"name":@"mobile",@"pk":@(YES)}];
self.mobileModel = [VVOrmModel ormModelWithClass:VVTestMobile.class
                                         manuals:@[column1]
                                        excludes:nil
                                       tableName:@"mobiles"
                                        dataBase:self.vvfmdb
                                          atTime:YES];

```
3. 使用ORM模型进行增删改查等操作.示例如下
```objc
NSInteger count = [self.mobileModel count:nil];
BOOL ret = [self.mobileModel increase:nil field:@"times" value:-1];
NSArray *array = [self.mobileModel findAll:nil orderBy:nil range:NSMakeRange(0, 10)];
...
```

## 生成Where语句
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
