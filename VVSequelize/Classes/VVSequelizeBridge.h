//
//  VVSequelizeBridge.h
//  Pods
//
//  Created by Jinbo Li on 2018/6/30.
//

#import <Foundation/Foundation.h>

@protocol VVSequelizeBridge <NSObject>

//MARK: - 数据库
@required
- (BOOL)db_createOrOpen:(NSString *)dbPath;
- (BOOL)db_open;
- (BOOL)db_close;
- (NSArray *)db_executeQuery:(NSString*)sql;
- (BOOL)db_executeUpdate:(NSString*)sql;

@optional
- (BOOL)db_setEncryptKey:(NSString *)encryptKey;
- (void)db_inDatabase:(void (^)(void))block;
- (void)db_inTransaction:(void (^)(BOOL *rollback))block;

//MAKR: - 模型对象互转
- (id)model_objectWithkeyValues:(NSDictionary *)keyValues class:(Class)cls;
- (id)model_objectArrayWithkeyValuesArray:(NSArray<NSDictionary *> *)keyValuesArray class:(Class)cls;
- (NSDictionary *)model_keyValuesOfObject:(id)object;
- (NSArray<NSDictionary *> *)model_keyValuesArrayWithObjectArray:(NSArray *)objectArray class:(Class)cls;

@end
