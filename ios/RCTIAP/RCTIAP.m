//
//  RCTIAP.m
//  RCTIAP
//
//  Created by lylleny on 2021/7/6.
//

#import "RCTIAP.h"

#define kIapUnverifyOrders  @"iap_unverify_orders"


@interface RCTIAP()<RCTBridgeModule,SKPaymentTransactionObserver,SKProductsRequestDelegate>
@property (nonatomic ,strong) NSArray *productList;
@property (nonatomic ,strong) NSMutableDictionary *callBackDictory;
@property (nonatomic ,copy) RCTResponseSenderBlock lostCallBack;
@end

@implementation RCTIAP

-(NSArray *)productList{
    if (!_productList) {
        _productList = [[NSArray alloc]init];
    }
    return  _productList;
}

-(NSMutableDictionary *)callBackDictory{
    if (!_callBackDictory) {
        _callBackDictory = [[NSMutableDictionary alloc]init];
    }
    return  _callBackDictory;
}

-(instancetype)init{
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return  self;
}


RCT_EXPORT_MODULE()
/**
 *  添加商品购买状态监听
 *  @params:
 *        callback 针对购买过程中，App意外退出的丢单数据的回调
 */
RCT_EXPORT_METHOD(addTransactionObserverWithCallback:(RCTResponseSenderBlock)callback) {
  // 监听商品购买状态变化
  [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  self.lostCallBack = callback;
}

/**
 *  服务器验证成功，删除缓存的凭证
 */
RCT_EXPORT_METHOD(removePurchase:(NSDictionary *)purchase) {
  NSMutableArray *iapUnverifyOrdersArray = [NSMutableArray array];
  if ([[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders] != nil) {
    [iapUnverifyOrdersArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders]];
  }
  for (NSDictionary *unverifyPurchase in iapUnverifyOrdersArray) {
    if ([unverifyPurchase[@"transactionIdentifier"] isEqualToString:purchase[@"transactionIdentifier"]]) {
      [iapUnverifyOrdersArray removeObject:unverifyPurchase];
    }
  }
  [[NSUserDefaults standardUserDefaults] setObject:[iapUnverifyOrdersArray copy] forKey:kIapUnverifyOrders];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)constantsToExport
{
  // 获取当前缓存的所有凭证
  NSMutableArray *iapUnverifyOrdersArray = [NSMutableArray array];
  if ([[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders] != nil) {
    [iapUnverifyOrdersArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders]];
  }
  return @{ @"iapUnverifyOrdersArray": iapUnverifyOrdersArray };
}

/**
 *  购买某个商品
 *  @params:
 *        productIdentifier: 商品id
 *        callback： 回调，返回
 */
RCT_EXPORT_METHOD(purchaseProduct:(NSString *)productIdentifier
                  callback:(RCTResponseSenderBlock)callback)
{
  
  NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
  if (transactions.count > 0) {
    //检测是否有未完成的交易
    SKPaymentTransaction* transaction = [transactions firstObject];
    if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
      [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
      return;
    }
  }
  
  SKProduct *product;
  for(SKProduct *p in self.products)
  {
    if([productIdentifier isEqualToString:p.productIdentifier]) {
      product = p;
      break;
    }
  }
  
  if(product) {
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    self.callBackDictory[RCTKeyForInstance(payment.productIdentifier)] = callback;
  } else {
    callback(@[@"无效商品"]);
  }
}

/**
 *  恢复购买
 */
RCT_EXPORT_METHOD(restorePurchases:(RCTResponseSenderBlock)callback)
{
  NSString *restoreRequest = @"restoreRequest";
  self.callBackDictory[RCTKeyForInstance(restoreRequest)] = callback;
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

/**
 *  加载所有可卖的商品
 */
RCT_EXPORT_METHOD(loadProducts:(NSArray *)productIdentifiers
                  callback:(RCTResponseSenderBlock)callback)
{
  if([SKPaymentQueue canMakePayments]){
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    self.callBackDictory[RCTKeyForInstance(productsRequest)] = callback;
    [productsRequest start];
  } else {
    callback(@[@"not_available"]);
  }
}

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray *)transactions
{
  
  RCTLog(@"=====TRANSACTIONS=====%@========%@",transactions,queue);

  for (SKPaymentTransaction *transaction in transactions) {
    RCTLog(@"=====TRANSACTIONS=====%@",transaction);
    switch (transaction.transactionState) {
      // 购买失败
      case SKPaymentTransactionStateFailed: {
        NSString *key = RCTKeyForInstance(transaction.payment.productIdentifier);
        RCTLog(@"==========SHIBAI=========%@",transaction);
        RCTResponseSenderBlock callback = self.callBackDictory[key];
        if (callback) {
          if(transaction.error.code != SKErrorPaymentCancelled){
            NSLog(@"购买失败");
            callback(@[@"购买失败"]);
          } else {
            NSLog(@"购买取消");
            callback(@[@"购买取消"]);
          }
          [self.callBackDictory removeObjectForKey:key];
        } else if(self.lostCallBack){
           self.lostCallBack(@[@"购买取消"]);
          [self.callBackDictory removeObjectForKey:key];

          RCTLogWarn(@"No callback registered for transaction with state failed.");
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        break;
      }
        // 购买成功
      case SKPaymentTransactionStatePurchased: {
        NSLog(@"购买成功");
        NSString *key = RCTKeyForInstance(transaction.payment.productIdentifier);
        RCTResponseSenderBlock callback = self.callBackDictory[key];
        
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        
        if (callback) {
  
          // 购买成功，获取凭证
          [self buyAppleStoreProductSucceedWithPaymentTransactionp:transaction callback:callback];
        } else if (_lostCallBack) {
          // 购买过程中出现意外App推出，下次启动App时的处理
          // 购买成功，获取凭证
          [self buyAppleStoreProductSucceedWithPaymentTransactionp:transaction callback:_lostCallBack];
        } else {
          RCTLogWarn(@"No callback registered for transaction with state purcahsed.");
        }
        
        break;
      }
        
        // 恢复购买
      case SKPaymentTransactionStateRestored:{
        NSLog(@"恢复购买成功");
        NSString *key = RCTKeyForInstance(transaction.payment.productIdentifier);
        RCTResponseSenderBlock callback = self.callBackDictory[key];
        if (callback) {
          callback(@[@"恢复购买成功"]);
          [self.callBackDictory removeObjectForKey:key];
        } else if(_lostCallBack){
          _lostCallBack(@[@"恢复购买成功"]);
          [self.callBackDictory removeObjectForKey:key];
          RCTLogWarn(@"No callback registered for transaction with state failed.");
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        break;
      }
        // 正在购买
      case SKPaymentTransactionStatePurchasing:
        NSLog(@"正在购买");
        break;
        
        // 交易还在队列里面，但最终状态还没有决定
      case SKPaymentTransactionStateDeferred:
        NSLog(@"推迟");
        break;
      default:
      RCTLogWarn(@"No callback default===========.");

        break;
    }
  }
}

// 苹果内购支付成功，获取凭证
- (void)buyAppleStoreProductSucceedWithPaymentTransactionp:(SKPaymentTransaction *)transaction callback:(RCTResponseSenderBlock)callback {
  NSString *key = RCTKeyForInstance(transaction.payment.productIdentifier);
  NSString *transactionReceiptString= nil;
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURLRequest * appstoreRequest = [NSURLRequest requestWithURL:[[NSBundle mainBundle]appStoreReceiptURL]];
    NSError *error = nil;
    NSData * receiptData = [NSURLConnection sendSynchronousRequest:appstoreRequest returningResponse:nil error:&error];
  
  if (!receiptData) {
    callback(@[@"获取交易凭证失败"]);
  } else {
    transactionReceiptString = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSDictionary *purchase = @{
                               @"transactionIdentifier": transaction.transactionIdentifier,
                               @"productIdentifier": transaction.payment.productIdentifier,
                               @"receiptData": transactionReceiptString
                               };
    // 将凭证缓存，后台验证结束后再删除
    RCTLog(@"'=========pusrse=========%@",purchase);
    NSMutableArray *iapUnverifyOrdersArray = [NSMutableArray array];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders] != nil) {
      [iapUnverifyOrdersArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kIapUnverifyOrders]];
    }
    [iapUnverifyOrdersArray addObject:purchase];
    [[NSUserDefaults standardUserDefaults] setObject:[iapUnverifyOrdersArray copy] forKey:kIapUnverifyOrders];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    callback(@[[NSNull null], purchase]);
    [self.callBackDictory removeObjectForKey:key];
  }
  
}

- (void)paymentQueue:(SKPaymentQueue *)queue
restoreCompletedTransactionsFailedWithError:(NSError *)error
{
  NSString *key = RCTKeyForInstance(@"restoreRequest");
  RCTResponseSenderBlock callback = self.callBackDictory[key];
  if (callback) {
    callback(@[@"恢复购买失败"]);
    [self.callBackDictory removeObjectForKey:key];
  } else if(_lostCallBack){
    self.lostCallBack(@[@"恢复购买失败"]);
    [self.callBackDictory removeObjectForKey:key];
    RCTLogWarn(@"No callback registered for restore product request.");
  }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
  NSString *key = RCTKeyForInstance(@"restoreRequest");
  RCTResponseSenderBlock callback = self.callBackDictory[key];
  if (callback) {
    NSMutableArray *productsArrayForJS = [NSMutableArray array];
    for(SKPaymentTransaction *transaction in queue.transactions){
      if(transaction.transactionState == SKPaymentTransactionStateRestored) {
        [productsArrayForJS addObject:transaction.payment.productIdentifier];
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
      }
    }
    callback(@[[NSNull null], productsArrayForJS]);
    [self.callBackDictory removeObjectForKey:key];
  } else if(_lostCallBack){
    NSMutableArray *productsArrayForJS = [NSMutableArray array];
    for(SKPaymentTransaction *transaction in queue.transactions){
      if(transaction.transactionState == SKPaymentTransactionStateRestored) {
        [productsArrayForJS addObject:transaction.payment.productIdentifier];
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
      }
    }
    self.lostCallBack(@[[NSNull null], productsArrayForJS]);
    [self.callBackDictory removeObjectForKey:key];
    RCTLogWarn(@"No callback registered for restore product request.");
  }
}

// 所有可卖商品回调
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
  NSString *key = RCTKeyForInstance(request);
  RCTResponseSenderBlock callback = self.callBackDictory[key];
  if (callback) {
    self.products = [response.products mutableCopy];
    NSMutableArray *productsArrayForJS = [NSMutableArray array];
    for(SKProduct *item in response.products) {
      NSDictionary *product = @{
                                @"identifier": item.productIdentifier,
                                @"priceString": item.priceString,
                                @"description": item.localizedDescription,
                                @"title": item.localizedTitle,
                                };
      [productsArrayForJS addObject:product];
    }
    callback(@[[NSNull null], productsArrayForJS]);
    [self.callBackDictory removeObjectForKey:key];
  } else {
    RCTLogWarn(@"No callback registered for load product request.");
  }
}

- (void)dealloc
{
  [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark Private

static NSString *RCTKeyForInstance(id instance)
{
  return [NSString stringWithFormat:@"%p", instance];
}
@end
