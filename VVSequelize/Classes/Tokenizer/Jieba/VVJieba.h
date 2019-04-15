//
//  VVJieba.h
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VVJieba : NSObject
+ (void)enumerateTokens:(const char *)string usingBlock:(void (^)(const char *token, uint32_t offset, uint32_t len, BOOL *stop))block;
@end

NS_ASSUME_NONNULL_END
