//
//  VVOrmModel.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVDataBase.h"

#define VVRangeAll NSMakeRange(0, 0)

/**
 数据表每个字段的配置.
 
 本项目中仅默认主键vv_pkid支持自增类型,所以此类中未定义自增属性.
 */
@interface VVOrmSchemaItem: NSObject
@property (nonatomic, copy  ) NSString *name;   ///< 字段名
@property (nonatomic, assign) BOOL notnull;     ///< 是否不为空,默认为NO(可为空)
@property (nonatomic, assign) BOOL pk;          ///< 是否主键
@property (nonatomic, assign) BOOL unique;      ///< 是否约束唯一
@property (nonatomic, copy  , nullable) NSString *type;   ///< 字段类型: TEXT,INTEGER,REAL,BLOB
@property (nonatomic, strong, nullable) id dflt_value;    ///< 默认值

/**
 生成字段配置
 
 @param dic 格式:{"name":"xxx","type":"TEXT","unique":@(YES),"notnull":@(YES),....}
 @return 字段配置
 */
+ (instancetype)schemaItemWithDic:(NSDictionary *)dic;


/**
 比较两个字段配置是否相同
 
 @param item 要比较的字段配置
 @return 是否相同
 */
- (BOOL)isEqualToItem:(VVOrmSchemaItem *)item;
@end

@interface VVOrmModel : NSObject
/**
 定义ORM模型.使用默认数据库,默认表名.
 
 @param cls 模型(Class)
 @param primaryKey 指定主键名,若cls无对应属性,则使用vv_pkid自增属性作为主键
 @return ORM模型
 @discussion 生成的模型将使用dbName和tableName生成的字符串作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,这先从模型池中查找.
 */
+ (instancetype)ormModelWithClass:(Class)cls
                       primaryKey:(NSString *)primaryKey;


/**
 定义ORM模型.使用自动主键,无额外选项.
 
 @param cls 模型(Class)
 @param primaryKey 指定主键名,若cls无对应属性,则使用vv_pkid自增属性作为主键
 @param tableName 表名,nil表示使用cls类名
 @param vvdb 数据库,nil表示使用默认数据库
 @return ORM模型
 @discussion 生成的模型将使用dbName和tableName生成的字符串作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,这先从模型池中查找.
 */
+ (instancetype)ormModelWithClass:(Class)cls
                       primaryKey:(NSString *)primaryKey
                        tableName:(nullable NSString *)tableName
                         dataBase:(nullable VVDataBase *)vvdb;

/**
 定义ORM模型.可自动新增字段,##不会修改或删除原有字段##.
 
 @param cls 模型(Class)
 @param manuals 自定义各个字段的配置.格式为VVOrmSchemaItem数组,或可转换为VVOrmSchemaItem的json数组.
 @param excludes 不存入数据表的字段名
 @param tableName 表名,nil表示使用cls类名
 @param vvdb 数据库,nil表示使用默认数据库
 @param atTime 是否将vv_createAt,vv_updateAt添加至每条数据,用于记录插入时间,更新时间,默认为YES
 @return ORM模型
 @discussion 生成的模型将使用dbName和tableName生成的字符串作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,这先从模型池中查找.
 */
+ (instancetype)ormModelWithClass:(Class)cls
                          manuals:(nullable NSArray *)manuals
                         excludes:(nullable NSArray *)excludes
                        tableName:(nullable NSString *)tableName
                         dataBase:(nullable VVDataBase *)vvdb
                           atTime:(BOOL)atTime;

/**
 删除表
 
 @return 是否删除成功
 */
- (BOOL)dropTable;

/**
 检查数据表是否存在
 
 @return 是否存在
 */
- (BOOL)isTableExist;

/**
 线程安全操作

 @param block 数据库操作
 @param completion 数据库操作完成之后的处理
 @discussion `ormModelWithClass`不能放入此操作
 */
- (void)inQueue:(nonnull id (^)(void))block
     completion:(nonnull void (^)(id ret))completion;

/**
 事务操作
 
 @param block 数据库事务操作
 @param completion 事务完成之后的处理
 @discussion `ormModelWithClass`不能放入此操作
 */
- (void)inTransaction:(nonnull id (^)(BOOL *rollback))block
           completion:(nonnull void (^)(BOOL rb,id ret))completion;

@end

@interface VVOrmModel (Create)

/**
 新增一条数据,对象或字典

 @param object 要新增的数据对象
 @return 是否新增成功
 */
-(BOOL)insertOne:(id)object;

/**
 新增多条数据

 @param objects 要新增的数据
 @return 是否新增成功
 */
-(BOOL)insertMulti:(NSArray *)objects;

@end

@interface VVOrmModel (Update)

/**
 根据条件更新数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param values 要设置的数据,格式为{"field1":data1,"field2":data2,...}
 @return 是否更新成功
 */
- (BOOL)update:(NSDictionary *)condition
        values:(NSDictionary *)values;

/**
 更新一条数据,更新不成功不会插入新数据.使用vv_pkid的表不能直接更新数据.
 
 @param object 要更新的数据
 @return 是否更新成功
 */
- (BOOL)updateOne:(id)object;

/**
 更新一条数据,更新失败会插入新数据.使用vv_pkid的表会直接新增数据.
 
 @param object 要更新的数据
 @return 是否更新或插入成功
 */
- (BOOL)upsertOne:(id)object;

/**
 更新多条数据,更新不成功不会插入新数据.使用vv_pkid的表不能直接更新数据.
 
 @param objects 要更新的数据
 @return 是否更新成功
 */
- (BOOL)updateMulti:(NSArray *)objects;

/**
 更新多条数据,更新失败会插入新数据.使用vv_pkid的表会直接新增数据.
 
 @param objects 要更新的数据
 @return 是否更新或插入成功
 */
- (BOOL)upsertMulti:(NSArray *)objects;

/**
 将某个字段的值增加某个数值
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param field 要更新的指端
 @param value 要增加的值,可为负数
 @return 是否增加成功
 */
- (BOOL)increase:(nullable NSDictionary *)condition
           field:(NSString *)field
           value:(NSInteger)value;

@end

@interface VVOrmModel (Retrieve)

/**
 查询一条数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 找到的数据
 */
- (nullable id)findOne:(nullable NSDictionary *)condition;


/**
 根据条件查询所有数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 查询结果
 */
- (NSArray *)findAll:(nullable NSDictionary *)condition;


/**
 根据条件查询数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @return 查询结果
 */
- (NSArray *)findAll:(nullable NSDictionary *)condition
             orderBy:(nullable NSDictionary *)orderBy
               range:(NSRange)range;


/**
 根据条件统计数据条数
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 数据条数
 */
- (NSInteger)count:(NSDictionary *)condition;


/**
 检查数据库中是否保存有某个数据
 
 @param object 数据对象
 @return 是否存在
 */
- (BOOL)isExist:(id)object;

/**
 根据条件查询数据和数据数量.数量只根据查询条件获取,不受range限制.
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @return 数据和数据数量,格式为{"count":100,list:[object]}
 */
- (NSDictionary *)findAndCount:(NSDictionary *)condition
                       orderBy:(NSDictionary *)orderBy
                         range:(NSRange)range;

/**
 最大行号`max(rowid)`

 @return 最大行号
 @discussion 此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid;

/**
 获取某个字段的最大值
 
 @param field 字段名
 @return 最大值.因Text也可以计算最大值,故返回值为id类型
 */
- (id)max:(NSString *)field;

/**
 获取某个字段的最小值
 
 @param field 字段名
 @return 最小值.因Text也可以计算最小值,故返回值为id类型
 */
- (id)min:(NSString *)field;

/**
 获取某个字段的求和
 
 @param field 字段名
 @return 求和
 */
- (id)sum:(NSString *)field;

@end

@interface VVOrmModel (Delete)

/**
 删除表
 
 @return 是否删除成功
 */
- (BOOL)drop;

/**
 删除一条数据
 
 @param object 要删除的数据
 @return 是否删除成功
 */
- (BOOL)deleteOne:(id)object;

/**
 删除多条数据
 
 @param objects 要删除的数据
 @return 是否删除成功
 */
- (BOOL)deleteMulti:(NSArray *)objects;


/**
 根据条件删除数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 是否删除成功
 */
- (BOOL)delete:(NSDictionary *)condition;

@end

