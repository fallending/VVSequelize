//
//  VVOrmView.h
//  VVSequelize
//
//  Created by Valo on 2020/4/23.
//

#import "VVOrm.h"

NS_ASSUME_NONNULL_BEGIN

#define VVORMVIEW_CUD_CHECK(obj) NSAssert(![(obj) isKindOfClass:VVOrmView.class], @"Unsupported by VVOrmView")

@interface VVOrmView : VVOrm
@property (nonatomic, strong) VVExpr *condition;
@property (nonatomic, assign) BOOL temporary;
@property (nonatomic, strong) NSArray *columns;

@property (nonatomic, assign, readonly) BOOL exist;

/// init view
/// @param viewName view name
/// @param orm source table orm
/// @param condition view condition
/// @param temporary temporary view or not
/// @param columns specify columns for view
- (instancetype)initWithName:(NSString *)viewName
                         orm:(VVOrm *)orm
                   condition:(VVExpr *)condition
                   temporary:(BOOL)temporary
                     columns:(nullable NSArray<NSString *> *)columns;

/// create view
- (BOOL)createView;

/// drop view
- (BOOL)dropView;

/// drop old view and create new view
- (BOOL)recreateView;

//MARK: - UNAVAILABLE

#define VVORMVIEW_UNAVAILABLE __attribute__((unavailable("This method is not supported by VVOrmView.")))

- (VVOrmInspection)inspectExistingTable VVORMVIEW_UNAVAILABLE;

- (void)setupTableWith:(VVOrmInspection)inspection VVORMVIEW_UNAVAILABLE;

- (void)createTable VVORMVIEW_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
