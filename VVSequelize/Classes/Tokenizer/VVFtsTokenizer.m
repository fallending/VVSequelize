//
//  VVFtsTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/4/1.
//

#import "VVFtsTokenizer.h"

@implementation VVFtsToken

- (void)dealloc
{
    if (_dup) {
        free((void *)_dup);
    }
}

@end
