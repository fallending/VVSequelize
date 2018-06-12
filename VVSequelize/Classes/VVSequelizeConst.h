//
//  VVSequelizeConst.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/11.
//

#import <Foundation/Foundation.h>

#define VVLog(...) [VVSequelizeConst VVVerbose:__VA_ARGS__]

@interface VVSequelizeConst : NSObject
@property (nonatomic, assign, class) BOOL verbose;

+ (void)VVVerbose:(NSString *)fmt, ...;

@end
