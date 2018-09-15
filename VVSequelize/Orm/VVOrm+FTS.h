//
//  VVOrm+FTS.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <VVSequelize/VVSequelize.h>

@interface VVOrm (FTS)
- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
             orderBy:(id)orderBy
               range:(NSRange)range;

- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
             groupBy:(id)groupBy
               range:(NSRange)range;

- (NSUInteger)count:(id)condition
              match:(NSString *)keyword;

- (NSDictionary *)findAndCount:(id)condition
                         match:(NSString *)keyword
                       orderBy:(id)orderBy
                         range:(NSRange)range;

- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
            distinct:(BOOL)distinct
              fields:(id)fields
             groupBy:(id)groupBy
              having:(id)having
             orderBy:(id)orderBy
               range:(NSRange)range;

@end
