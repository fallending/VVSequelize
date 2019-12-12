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
/// @param method tokenizer
- (BOOL)registerMethod:(VVTokenMethod)method forTokenizer:(NSString *)name;

/// get tokenzier by name
- (VVTokenMethod)methodForTokenizer:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
