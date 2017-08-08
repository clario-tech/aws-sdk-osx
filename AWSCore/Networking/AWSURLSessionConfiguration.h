//
//  AWSURLSessionConfiguration.h
//  AWSS3
//
//  Created by Vitaly Afanasyev on 8/7/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AWSURLSessionConfiguration : NSObject<NSCopying>

/* identifier for the background session configuration */
@property (nullable, readonly, copy) NSString *identifier;

@property (class, readonly, strong) AWSURLSessionConfiguration *defaultSessionConfiguration;

/* The URL resource cache, or nil to indicate that no caching is to be performed */
@property (nullable, retain) NSURLCache *URLCache;

/* default timeout for requests.  This will cause a timeout if no data is transmitted for the given timeout value, and is reset whenever data is transmitted. */
@property NSTimeInterval timeoutIntervalForRequest;

/* default timeout for requests.  This will cause a timeout if a resource is not able to be retrieved within a given timeout. */
@property NSTimeInterval timeoutIntervalForResource;

+ (instancetype)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
