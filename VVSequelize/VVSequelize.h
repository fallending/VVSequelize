#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#ifdef VVSEQUELIZE_CORE
#import "VVSequelize+Core.h"
#endif

#ifdef VVSEQUELIZE_FTS
#import "VVSequelize+FTS.h"
#endif

#ifdef VVSEQUELIZE_UTIL
#import "VVSequelize+Util.h"
#endif

FOUNDATION_EXPORT double VVSequelizeVersionNumber;
FOUNDATION_EXPORT const unsigned char VVSequelizeVersionString[];
