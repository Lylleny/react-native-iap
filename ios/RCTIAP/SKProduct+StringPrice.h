//
//  SKProduct+StringPrice.h
//  react-native-iap
//
//  Created by lylleny on 2021/7/6.
//

#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKProduct (StringPrice)
@property (nonatomic,readonly) NSString *priceString;
@end

NS_ASSUME_NONNULL_END
