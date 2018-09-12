//
//  VVOrmModel+Create.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel+Create.h"
#import "NSObject+VVKeyValue.h"

@implementation VVOrmModel (Create)
-(BOOL)insertOne:(id)object{
    BOOL ret = [self innerInsertOne:object];
    [self handleResult:ret action:VVOrmActionInsert];
    return ret;
}

-(BOOL)innerInsertOne:(id)object{
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
    NSMutableString *valString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.config.fieldNames containsObject:key]){
            [keyString appendFormat:@"\"%@\",",key];
            [valString appendFormat:@"?,"];
            [values addObject:[obj vv_dbStoreValue]];
        }
    }];
    if(keyString.length > 1 && valString.length > 1){
        if(self.config.logAt){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [keyString appendFormat:@"\"%@\",",kVsCreateAt];
            [valString appendFormat:@"?,"];
            [values addObject:@(now)];
            [keyString appendFormat:@"\"%@\",",kVsUpdateAt];
            [valString appendFormat:@"?,"];
            [values addObject:@(now)];
        }
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) VALUES (%@)",self.tableName,keyString,valString];
        return [self.vvdb executeUpdate:sql values:values];
    }
    return NO;
}

-(NSUInteger)insertMulti:(NSArray *)objects{
    NSUInteger succCount = 0;
    for (id obj in objects) {
        if([self innerInsertOne:obj]){ succCount ++;}
    }
    [self handleResult:succCount > 0 action:VVOrmActionInsert];
    return succCount;
}

@end
