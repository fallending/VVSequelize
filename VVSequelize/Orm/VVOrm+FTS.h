//
//  VVOrm+FTS.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <VVSequelize/VVSequelize.h>

FOUNDATION_EXPORT NSString * const VVOrmFtsCount;
FOUNDATION_EXPORT NSString * const VVOrmFtsOffsets;
FOUNDATION_EXPORT NSString * const VVOrmFtsSnippet;

@interface VVOrm (FTS)

/**
 全文搜索

 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @param orderBy 排序方式
 @param range 范围,用于分页
 @param attrs 对于匹配的字符串添加相应属性,返回值里面会多一项数据"<field>_attrText"
 @return 匹配结果,格式:[json]
 @note  fts3,fts4,返回数据含:"vvorm_fts_offsets",对应offset()函数的值."<field>_attrText",对应字段添加了相应属性的富文本.
        fts5 返回数据包含:"vvorm_fts_snippet" 对应snippet()函数的值
 */
- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           orderBy:(id)orderBy
             range:(NSRange)range
        attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;


/**
 分组全文搜索
 
 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @param groupBy 分组方式
 @param range 范围,用于分页
 @param attrs 对于匹配的字符串添加相应属性,返回值里面会多一项数据"<field>_attrText"
 @return 匹配结果,含分组的匹配数量"vvorm_fts_count",格式:[json]
 @note  fts3,fts4,返回数据含:"vvorm_fts_offsets",对应offset()函数的值."<field>_attrText",对应字段添加了相应属性的富文本.
        fts5 返回数据包含:"vvorm_fts_snippet" 对应snippet()函数的值
 */
- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           groupBy:(id)groupBy
             range:(NSRange)range
        attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;

/**
 获取匹配数量

 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @return 匹配数量
 */
- (NSUInteger)matchCount:(NSString *)pattern
               condition:(id)condition;

/**
 全文搜索
 
 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @param orderBy 排序方式
 @param range 范围,用于分页
 @param attrs 对于匹配的字符串添加相应属性,返回值里面会多一项数据"<field>_attrText"
 @return 匹配结果,数据(字典数组)和数据数量,格式:{"count":100,list:[json]}
 @note  fts3,fts4,返回数据含:"vvorm_fts_offsets",对应offset()函数的值."<field>_attrText",对应字段添加了相应属性的富文本.
        fts5 返回数据包含:"vvorm_fts_snippet" 对应snippet()函数的值
 */
- (NSDictionary *)matchAndCount:(NSString *)pattern
                      condition:(id)condition
                        orderBy:(id)orderBy
                          range:(NSRange)range
                     attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;


//MARK: - 处理FTS3,4的offsets()
+ (NSDictionary<NSString *, NSArray *> *)cRangesWithOffsetString:(NSString *)offsetsString;

+ (NSAttributedString *)attrTextWith:(NSString *)text
                             cRanges:(NSArray *)offsets
                               attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;

@end
