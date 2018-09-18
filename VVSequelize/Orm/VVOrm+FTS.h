//
//  VVOrm+FTS.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <VVSequelize/VVSequelize.h>

FOUNDATION_EXPORT NSString * const VVOrmFtsCount;

@interface VVOrm (FTS)

/**
 全文搜索

 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @param orderBy 排序方式
 @param range 范围,用于分页
 @return 匹配结果,对象数组,格式:[object]
 */
- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           orderBy:(id)orderBy
             range:(NSRange)range;


/**
 分组全文搜索
 
 @param pattern match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param condition 除match外的常规搜索条件
 @param groupBy 分组方式
 @param range 范围,用于分页
 @return 匹配结果,含分组的匹配数量"vvorm_fts_count",格式:[json]
 @note 使用`+vv_objectsWithKeyValuesArray:`获取对象数组,`dic[VVOrmFtsCount]`获取分组匹配数量
 */
- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           groupBy:(id)groupBy
             range:(NSRange)range;

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
 @return 匹配结果,数据(对象数组)和数据数量,格式:{"count":100,list:[object]}
 */
- (NSDictionary *)matchAndCount:(NSString *)pattern
                      condition:(id)condition
                        orderBy:(id)orderBy
                          range:(NSRange)range;


//MARK: - 对FTS搜索结果进行处理

//MARK: 使用C语言方式处理FTS3,4的offsets()

/**
 处理从offsets()函数获取到的匹配数据

 @param offsetsString offsets匹配数据
 @return cstring 的匹配范围,格式:{fieldIdx:cranges}
 */
+ (NSDictionary<NSString *, NSArray *> *)cRangesWithOffsetsString:(NSString *)offsetsString;

/**
 对String进行处理,生成富文本.

 @param string 原始文本
 @param cRanges 由`+cRangesWithOffsetString:`处理后的cRanges
 @param attrs 需要添加的富文本属性
 @return 富文本
 */
+ (NSAttributedString *)attributedStringWith:(NSString *)string
                                     cRanges:(NSArray *)cRanges
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;

//MARK: 使用Objective-C处理
/**
 由FTS搜索的keyword生成正则表达式,用于对搜索结果进行高亮,加粗等操作

 @param keyword FTS搜索关键词,可包含`*`,`?`
 @return 正则表达式,将keyword中的`*`替换为`.*`, `?`替换为`.`
 */
+ (NSString *)regularExpressionForKeyword:(NSString *)keyword;

/**
 根据正则表达式匹配并生成富文本

 @param string 原始文本
 @param prefix 前缀,某些场景可能需要
 @param regex 正则表达式
 @param attrs 添加的属性,比如颜色,字体等
 @return 富文本
 */
+ (NSAttributedString *)attributedStringWith:(NSString *)string
                                      prefix:(NSString *)prefix
                                       match:(NSString *)regex
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs;

@end
