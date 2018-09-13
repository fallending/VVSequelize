//
//  VVOrmField.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, VVOrmPkType) {
    VVOrmPkNone = 0,
    VVOrmPkNormal,
    VVOrmPkAutoincrement,
};

@interface VVOrmField: NSObject
@property (nonatomic, copy) NSString *name;     ///< 字段名
@property (nonatomic, copy) NSString *type;     ///< 字段类型: TEXT,INTEGER,REAL,BLOB,可加长度限制

/**
 生成字段配置
 
 @param dictionary 通常为从数据库中查询得到的表结构.格式:{"name":"xxx","type":"TEXT","unique":@(YES),"notnull":@(YES)}
 @return 字段配置
 */
+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary;

/**
 比较两个字段配置是否相同
 
 @param field 要比较的字段配置
 @return 是否相同
 */
- (BOOL)isEqualToField:(VVOrmField *)field;

@end

