//
//  VVFtsEnumerator.h
//  VVSequelize
//
//  Created by Valo on 2019/8/9.
//

#import <Foundation/Foundation.h>
#import "VVFtsTokenizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVFtsEnumerator : NSObject

+ (void)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end handler:(VVFtsXTokenHandler)handler;

+ (NSArray<VVFtsToken *> *)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end;

+ (void)enumerateNumbers:(NSString *)whole handler:(VVFtsXTokenHandler)handler;

@end

NS_ASSUME_NONNULL_END
