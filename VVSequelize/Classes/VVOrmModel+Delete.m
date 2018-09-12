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
    NSString *primaryKey =self.config.primaryKey;
    if(primaryKey.length == 0) return NO;
    id pk = [object valueForKey:primaryKey];
    if(!pk) return NO;
    NSString *where = [VVSqlGenerator where:@{primaryKey:pk}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret;
}

- (BOOL)deleteMulti:(NSArray *)objects{
    NSString *primaryKey =self.config.primaryKey;
    if(primaryKey.length == 0) return NO;
    NSMutableArray *pks = [NSMutableArray arrayWithCapacity:0];
    for (id object in objects) {
        id pk = [object valueForKey:primaryKey];
        if(pk) [pks addObject:pk];
    }
    if(pks.count == 0) return YES;
    NSString *where = [VVSqlGenerator where:@{primaryKey:@{kVsOpIn:pks}}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret;
}

- (BOOL)delete:(id)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",self.tableName, where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionDelete];
    return ret;
}

@end
