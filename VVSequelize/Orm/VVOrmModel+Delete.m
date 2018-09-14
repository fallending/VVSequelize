//
//  VVOrmModel+Delete.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel+Delete.h"
#import "VVSqlGenerator.h"

@implementation VVOrmModel (Delete)
- (BOOL)drop{
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS \"%@\"",self.tableName];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    if(ret){
        // 此处还需发送表删除通知
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelTableDeletedNotification object:self];
    }
    return ret;
}

- (BOOL)deleteOne:(id)object{
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if(condition.count == 0) return NO;
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret;
}

- (NSUInteger)deleteMulti:(NSArray *)objects{
    NSString *key = self.config.primaryKey;
    if(key.length == 0) key = self.config.uniques.firstObject;
    if(key.length == 0) return 0;
    NSMutableArray *vals = [NSMutableArray arrayWithCapacity:0];
    for (id object in objects) {
        id val = [object valueForKey:key];
        if(val) [vals addObject:val];
    }
    if(vals.count == 0) return 0;
    NSString *where = [VVSqlGenerator where:@{key:@{kVsOpIn:vals}}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret ? vals.count : 0;
}

- (BOOL)delete:(id)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret;
}

@end
