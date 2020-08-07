//
//  VVDataBase+FTS.h
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase.h"
#import "VVTokenEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVDatabase (FTS)

/// register tokenizer, fts3/4/5
- (BOOL)registerEnumerator:(Class<VVTokenEnumerator>)enumerator forTokenizer:(NSString *)name;

- (nullable Class<VVTokenEnumerator>)enumeratorForTokenizer:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
