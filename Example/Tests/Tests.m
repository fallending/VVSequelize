//
//  VVSequelizeTests.m
//  VVSequelizeTests
//
//  Created by Valo on 03/13/2019.
//  Copyright (c) 2019 Valo. All rights reserved.
//

#import <VVSequelize/VVSequelize.h>

@import XCTest;

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{

    NSArray *texts = @[@"在空指针上调用这个函数没有什么影响",
                       @"同时可以准备语句的生命周期的任一时刻调用这个函数",
                       @"在语句被执行前，一次或多次调用sqlite_reset之后",
                       @"或者在sqlite3_step任何调用之后不管语句是否完成执行",
                       @"腾讯云是腾讯智慧产业解决方案的基础",
                       @"腾讯将云计算技术与AI及数据分析功能结合，协助不同行业的数字化转型",
                       @"腾讯的网络安全功能令云解决方案更为稳定及可靠。2018年，凭借腾讯的行业专业知识及坚稳的基础设施",
                       @"腾讯云在网络游戏及视频流媒体等垂直领域保持市场领先地位。目前，腾讯为超过一半的中国游戏公司提供服务，并正在拓展海外市场。透过在垂直领域的战略性合作，腾讯迅速扩大了互联网服务的客户基础。",
                       @"主要范畴包括电商、资讯社交、手机制造商应用商店及智慧交通。腾讯进一步扩大了在金融及零售等其他重要行业的业务。腾讯是中行、建行及招行等头部银行的首选合作伙伴。大部分的头部互联网金融和保险公司是腾讯的客户",
                       @"腾讯基于腾讯独特的资源（如公众号及小程序）搭建零售云解决方案，以帮助零售商提高消费者参与度，凭借腾讯的目标消费者精准定向功能及防诈骗技术，帮助其提升营销投资回报率，并利用AI、LBS及大数据技术协助客户内部营运升级"];
    for (NSString *text in texts) {
        CFAbsoluteTime begin = CFAbsoluteTimeGetCurrent();
        NSString *pinyin = [text pinyin];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        NSLog(@"time: %@, string: %@", @(end - begin), @(pinyin.length));
    }
}

- (void)testExample1
{
    
    NSArray *texts = @[@"成都",@"成都",@"曾东",@"曾重都"];
    for (NSString *text in texts) {
        CFAbsoluteTime begin = CFAbsoluteTimeGetCurrent();
        NSArray *pinyins = [text pinyinsForTokenize];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        NSLog(@"time: %@, string: %@", @(end - begin), pinyins);
    }
}

@end

