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

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           orderBy:(id)orderBy
             range:(NSRange)range;

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           groupBy:(id)groupBy
             range:(NSRange)range;

- (NSUInteger)matchCount:(NSString *)pattern
               condition:(id)condition;

- (NSDictionary *)matchAndCount:(NSString *)pattern
                      condition:(id)condition
                        orderBy:(id)orderBy
                          range:(NSRange)range;

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
          distinct:(BOOL)distinct
            fields:(id)fields
           groupBy:(id)groupBy
            having:(id)having
           orderBy:(id)orderBy
             range:(NSRange)range;

//MARK: - 处理FTS3,4的offsets()
+ (NSDictionary<NSString *, NSArray *> *)cRangesWithOffsetString:(NSString *)offsetsString;

+ (NSAttributedString *)attrTextWith:(NSString *)text
                             cRanges:(NSArray *)offsets
                               color:(NSDictionary<NSAttributedStringKey, id> *)attrs;

@end
