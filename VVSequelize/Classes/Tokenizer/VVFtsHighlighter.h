//
//  VVFtsHighlighter.h
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import <Foundation/Foundation.h>
#import "VVOrm.h"
#import "VVTokenEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVFtsHighlighter : NSObject
@property (nonatomic, assign) VVTokenMethod method;
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, assign) BOOL pinyin;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *highlightAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *normalAttributes;
@property (nonatomic, strong) id reserved;

- (instancetype)initWithOrm:(VVOrm *)orm
                    keyword:(NSString *)keyword
        highlightAttributes:(NSDictionary<NSAttributedStringKey, id> *)highlightAttributes;

- (instancetype)initWithMethod:(VVTokenMethod)method
                       keyword:(NSString *)keyword
           highlightAttributes:(NSDictionary<NSAttributedStringKey, id> *)highlightAttributes;

/**
 对FTS搜索结果进行高亮

 @param objects 要进行高亮处理的对象数组
 @param field 要进行高亮的对象字段
 @return 高亮结果,属性文本数组,和objects顺序一致
 */
- (NSArray<NSAttributedString *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field;

/**
 对单条FTS结果进行高亮

 @param source 要进行高亮处理的单条文本
 @param hits 命中次数
 @return 高亮结果,属性文本
 */
- (NSAttributedString *)highlight:(NSString *)source hits:(nullable BOOL *)hits;

@end

NS_ASSUME_NONNULL_END
