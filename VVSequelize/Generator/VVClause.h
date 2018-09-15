//
//  VVClause.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <Foundation/Foundation.h>

@interface VVClause : NSObject

/**
 创建子句

 @param value 用于生成子句的对象,可以是NSString, NSDictionary, NSArray
 @return VVClause子句对象
 */
+ (instancetype)prepare:(id)value;

/**
 根据传入的数据生成where子句
 
 @return where子句,不包含`where`关键字
 */
- (NSString *)condition;

/**
 根据传入的数据生成where子句

 @return where子句,包含`where`关键字
 */
- (NSString *)where;

/**
 根据传入的数据生成groupBy子句
 
 @return groupBy子句,包含`group by`关键字
 */
- (NSString *)groupBy;

/**
 根据传入的数据生成having子句
 
 @return having子句,包含`having`关键字
 */
- (NSString *)having;

/**
 根据传入的数据生成orderBy子句
 
 @return orderBy子句,包含`order by`关键字
 */
- (NSString *)orderBy;


@end
