//
//  VVSqlGenerator.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/13.
//

#import <Foundation/Foundation.h>

#define kVsOpAnd @"$and"
#define kVsOpOr @"$or"
#define kVsOpGt @"$gt"
#define kVsOpGte @"$gte"
#define kVsOpLt @"$lt"
#define kVsOpLte @"$lte"
#define kVsOpNe @"$ne"
#define kVsOpNot @"$not"
#define kVsOpBetween @"$between"
#define kVsOpNotBetween @"$notBetween"
#define kVsOpIn @"$in"
#define kVsOpNotIn @"$notIn"
#define kVsOpLike @"$like"
#define kVsOpNotLike @"$notLike"

#define kVsOrderAsc @"ASC"
#define kVsOrderDesc @"DESC"

/**
 SQL语句生成器
 */
@interface VVSqlGenerator : NSObject


/**
 @brief 将条件转换为Where语句.
 @brief 转换后,SQL关键字使用大写;所有的key和val都使用双引号进行包含,避免传入一些特殊字符,导致查询失败.
 
 @brief 操作符说明:
 @brief {"$and": {"a": 5}} -> AND ("a" = "5")
 @brief {"$or": [{"a": 5}, {"a": 6}]} -> ("a" = "5" OR "a" = "6")
 @brief {"$gt": 6} -> > "6"
 @brief {"$gte": 6} -> >= "6"
 @brief {"$lt": 10} -> < "10"
 @brief {"$lte": 10} -> <= "10"
 @brief {"$ne": 20}  -> != "20"
 @brief {"$not": YES} -> IS NOT "1"
 @brief {"$between": [6, 10]} -> BETWEEN "6" AND "10"
 @brief {"$notBetween": [11, 15]} -> NOT BETWEEN "11" AND "15"
 @brief {"$in": [1, 2]} -> IN ("1", "2")
 @brief {"$notIn": [1, 2]} -> NOT IN ("1", "2")
 @brief {"$like": "%hat"} -> LIKE "%hat"
 @brief {"$notLike": "%hat"} -> NOT LIKE "%hat"
 
 @brief 示例:
 @brief {"name":"zhangsan", "age":26} -> ("name" = "zhangsan" AND "age" = "26")
 @brief {"$or":[{"name":"zhangsan","age":26},{"age":30}]} -> (("name" = "zhangsan" AND "age" = "26") OR "age" = "30")
 @brief {"age":{"$lt":(30)}} -> "age" < "30"
 @brief {"type":{"$in":["a","b","c"]}} -> "type" IN ("a","b","c")
 
 @param condition 自定义条件
 @return where语句
 */
+ (NSString *)where:(NSDictionary *)condition;


/**
 @brief 生成排序语句

 @brief 示例:
 @brief {"age":"ASC","score":"DESC"} -> ORDER BY "age" ASC,"score" DESC
 
 @param orderBy 排序条件
 @return 排序语句
 */
+ (NSString *)orderBy:(NSDictionary *)orderBy;


/**
 @brief 生成分页限制语句

 @brief 示例:
 @brief (100,20) -> LIMIT 100,20
 
 @param range 数据范围,range.length为0时不限制
 @return 分页限制语句
 */
+ (NSString *)limit:(NSRange)range;

@end
