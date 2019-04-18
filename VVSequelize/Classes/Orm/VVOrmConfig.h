//
//  VVOrmConfig.h
//  VVSequelize
//
//  Created by Valo on 2018/9/10.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const kVVCreateAt;       ///< 数据库字段,数据创建时间
FOUNDATION_EXPORT NSString *const kVVUpdateAt;       ///< 数据库字段,数据更新时间

@class VVDatabase;
@interface VVOrmConfig : NSObject

@property (nonatomic, strong) Class cls;      ///< 对应的模型(Class)
@property (nonatomic, assign) BOOL logAt;     ///< 是否自动记录时间,默认为NO

//MARK: fts表配置相关
@property (nonatomic, assign) BOOL fts;              ///< 是否FTS表,默认为NO
@property (nonatomic, copy) NSString *ftsModule;     ///< FTS模块:fts3,fts4,fts5...默认为fts5
@property (nonatomic, copy) NSString *ftsTokenizer;  ///< FTS分词器:porter,unicode61,icu,...

//MARK: 创建表时使用的参数,可设置
@property (nonatomic, assign) BOOL pkAutoIncrement;  ///< 主键是否自增,仅单主键有效
@property (nonatomic, strong) NSArray<NSString *> *primaries; ///< 主键字段
@property (nonatomic, strong) NSArray<NSString *> *whiteList; ///< 白名单,数据表中需要保存的字段
@property (nonatomic, strong) NSArray<NSString *> *blackList; ///< 黑名单,数据表中不需要保存的字段.白名单存在时,以白名单为准
@property (nonatomic, strong) NSArray<NSString *> *notnulls;  ///< 非空约束
@property (nonatomic, strong) NSArray<NSString *> *uniques;   ///< 唯一性约束的字段
@property (nonatomic, strong) NSArray<NSString *> *indexes;   ///< 具有索引的字段(不含唯一性约束字段),FTS表示需要索引的字段
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *types; ///< 字段类型,{字段:类型字符串}
@property (nonatomic, strong) NSDictionary<NSString *, id> *defaultValues; ///< 默认值,{字段:默认值}

//MARK: 只读属性
@property (nonatomic, assign, readonly) NSUInteger ftsVersion; ///< FTS模块版本:3,4,5. @note 模块名有可能为fts4aux
@property (nonatomic, assign, readonly) BOOL fromTable;        ///< 是否是由数据表生成的配置
@property (nonatomic, strong, readonly) NSArray<NSString *> *columns; ///< 所有字段名,按sqlite存储顺序排列,格式:[字段名]

//MARK: - Public
/**
 从数据表获取配置
 
 @param tableName 表名
 @param vvdb 数据库
 @return ORM配置
 */
+ (instancetype)configFromTable:(NSString *)tableName
                       database:(VVDatabase *)vvdb;

/**
 创建ORM配置
 
 @param cls 数据表要存储的类
 @return ORM配置
 */
+ (instancetype)configWithClass:(Class)cls;

/**
 创建ORM配置
 
 @param cls 数据表要存储的类
 @param module fts模块:fts3,fts4,fts5...默认为fts5
 @param tokenizer FTS分词器:porter,unicode61,icu,需在database注册
 @param indexes 需要全文索引的字段,仅在fts4以上版本有效,
 @return ORM配置
 */
+ (instancetype)ftsConfigWithClass:(Class)cls
                            module:(NSString *)module
                         tokenizer:(NSString *)tokenizer
                           indexes:(NSArray<NSString *> *)indexes;

/**
 处理配置.去重,处理黑白名单等.
 */
- (void)dispose;

/**
 是否和相比较的ORM配置一致
 
 @param config 做对比的ORM配置
 @return 是否一致
 */
- (BOOL)isEqualToConfig:(VVOrmConfig *)config;

/**
 比较index是否一致
 
 @param config 做比较的ORM配置
 @return 是否一致
 */
- (BOOL)isInedexesEqual:(VVOrmConfig *)config;

/**
 生成普通表建表sql语句
 
 @param tableName 表名
 @return 建表sql语句
 */
- (NSString *)createSQLWith:(NSString *)tableName;

/**
 生成FTS表建表sql语句
 
 @param tableName 表名
 @return 建表sql语句
 */
- (NSString *)createFtsSQLWith:(NSString *)tableName;

@end
