//
//  VVOrmConfig.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import <Foundation/Foundation.h>
#import "VVOrmField.h"

#define kVsCreateAt     @"vv_createAt"      ///< 数据库字段,数据创建时间
#define kVsUpdateAt     @"vv_updateAt"      ///< 数据库字段,数据更新时间

@class VVDataBase;
@interface VVOrmConfig : NSObject

@property (nonatomic, strong) Class    cls;            ///< 对应的模型(Class)
@property (nonatomic, copy  ) NSString *primaryKey;    ///< 主键名
@property (nonatomic, copy  ) NSString *ftsModule;     ///< 设置FTS模块:fts3,fts4,fts5.默认为nil,不使用fts模块.
@property (nonatomic, copy  ) NSString *ftsTokenizer;  ///< 设置FTS分词器:porter,unicode61,..., 必须在fts模块启用时有效,且当前sqlite3库支持
@property (nonatomic, assign) BOOL   logAt;            ///< 是否自动记录时间,默认为YES
@property (nonatomic, copy, readonly) NSDictionary<NSString *,VVOrmField *> *fields;     ///< 字段配置,格式为 {字段名:配置}
@property (nonatomic, copy, readonly) NSArray<NSString *>                   *fieldNames; ///< 字段名

/**
 从数据表获取配置

 @param tableName 表名
 @param vvdb 数据库
 @return ORM配置
 */
+ (instancetype)configWithTable:(NSString *)tableName
                     inDatabase:(VVDataBase *)vvdb;

/**
 初始化ORM配置

 @param cls 数据表要存储的类
 @return ORM配置
 */
+ (instancetype)prepareWithClass:(Class)cls;

/**
 是否和相比较的ORM配置一致

 @param config 作对比的ORM配置
 @param indexChanged 是否需要更新索引
 @return 是否一致
 */
- (BOOL)compareWithConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged;

//MARK: - 链式调用

/**
 设置主键

 @param primaryKey 主键名
 @return ORM配置
 */
- (instancetype)primaryKey:(NSString *)primaryKey;

/**
 设置唯一性约束的字段

 @param uniques 唯一性约束的字段
 @return ORM配置
 */
- (instancetype)uniques:(NSArray<NSString *> *)uniques;

/**
 配置不保存的字段

 @param excludes 不保存的字段
 @return ORM配置
 */
- (instancetype)excludes:(NSArray<NSString *> *)excludes;

/**
 配置自定义的字段

 @param manuals 配置自定义字段
 @return ORM配置
 */
- (instancetype)manuals:(NSArray<VVOrmField *> *)manuals;

/**
 配置是否记录插入/更新时间

 @param logAt 是否记录插入/更新时间
 @return ORM配置
 */
- (instancetype)logAt:(BOOL)logAt;

/**
 设置FTS模块

 @param ftsModule FTS模块名,fts3,fts4,fts5
 @param tokenizer FTS分词器名,porter,unicode61,icu,...可为nil,必须是当前sqlite3库支持的.
 @return ORM配置
 */
- (instancetype)ftsModule:(NSString *)ftsModule tokenizer:(NSString *)tokenizer;

@end
