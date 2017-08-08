//
//  AWSJSONSerialization.h
//  AWSCore
//
//  Created by Vitaly Afanasyev on 8/8/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, AWSJSONWritingOptions) {
	AWSJSONWritingPrettyPrinted = (1UL << 0)
};


@interface AWSJSONSerialization : NSObject

+ (nullable NSData *)dataWithJSONObject:(id)obj options:(AWSJSONWritingOptions)opt error:(NSError **)error;
+ (nullable id)JSONObjectWithData:(NSData *)data options:(AWSJSONWritingOptions)opt error:(NSError **)error;

+ (BOOL)isValidJSONObject:(id)obj;

@end

NS_ASSUME_NONNULL_END
