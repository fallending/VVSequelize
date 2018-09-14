//
//  VVTestDBClass.m
//  VVSequelize_Tests
//
//  Created by Jinbo Li on 2018/9/14.
//  Copyright © 2018年 Valo Lee. All rights reserved.
//

#import "VVTestDBClass.h"
#import <FMDB/FMDB.h>


@interface VVTestDBClass ()
@property (nonatomic, strong) FMDatabase *fmdb;
@end

@implementation VVTestDBClass

+ (instancetype)dbWithPath:(NSString *)path{
    VVTestDBClass *dbClass = [[VVTestDBClass alloc] init];
    dbClass.fmdb = [FMDatabase databaseWithPath:path];
    return dbClass;
}

- (BOOL)open{
    return [_fmdb open];
}

- (BOOL)openWithFlags:(int)flags{
    return [_fmdb openWithFlags:flags];
}

- (BOOL)setEncryptKey:(NSString * _Nullable)encryptKey {
    return [_fmdb setKey:encryptKey];
}

- (BOOL)close{
    return [_fmdb close];
}

- (NSArray *)executeQuery:(NSString *)sql error:(NSError *__autoreleasing  _Nullable *)error{
    FMResultSet *set = [_fmdb executeQuery:sql values:nil error:error];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    while ([set next]) {
        [array addObject:set.resultDictionary];
    }
    return array;
}

- (BOOL)executeUpdate:(NSString *)sql error:(NSError *__autoreleasing  _Nullable *)error{
    return [_fmdb executeUpdate:sql values:nil error:error];
}

- (BOOL)executeUpdate:(NSString *)sql values:(NSArray *)values error:(NSError *__autoreleasing  _Nullable *)error{
    return [_fmdb executeUpdate:sql values:values error:error];
}

@end
