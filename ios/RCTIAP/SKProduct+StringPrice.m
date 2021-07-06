//
//  SKProduct+StringPrice.m
//  react-native-iap
//
//  Created by lylleny on 2021/7/6.
//

#import "SKProduct+StringPrice.h"

@implementation SKProduct (StringPrice)
-(NSString *)priceString{
    NSNumberFormatter *form = [[NSNumberFormatter alloc]init];
    form.formatterBehavior = NSNumberFormatterBehavior10_4;
    form.numberStyle = NSNumberFormatterCurrencyStyle;
    form.locale = self.priceLocale;
    return  [form stringFromNumber: self.price];
}

@end
