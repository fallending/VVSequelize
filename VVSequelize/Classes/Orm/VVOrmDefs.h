//
//  VVOrmDefs.h
//  VVSequelize
//
//  Created by Valo on 2019/4/2.
//

#import <Foundation/Foundation.h>

#ifndef $
#define $(field) NSStringFromSelector(@selector(field))
#endif

// VVExpr 查询表达式, where/having子句
// NSString,原生sql,可传入`where`及之后的所有语句
// NSDictionary,非套嵌,key和value用`=`连接,不同的key value用`and`连接
// NSArray,非套嵌的dictionary数组, 每个dictionary用`or`连接
typedef NSObject   VVExpr;

// VVFields 指定查询的字段
// NSString: `"field1","field2",...`, `count(*) as count`, ...
// NSArray: ["field1","field2",...]
typedef NSObject   VVFields;

// VVOrderBy 排序表达式
// NSString: "field1 asc", "field1,field2 desc", "field1 asc,field2,field3 desc", ...
// NSArray:  ["field1 asc","field2,field3 desc",...]
typedef NSObject   VVOrderBy;

// VVGroupBy 分组表达式
// NSString: "field1","field2",...
// NSArray:  ["field1","field2",...]
typedef NSObject   VVGroupBy;
