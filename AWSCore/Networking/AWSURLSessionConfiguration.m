//
//  AWSURLSessionConfiguration.m
//  AWSS3
//
//  Created by Vitaly Afanasyev on 8/7/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import "AWSURLSessionConfiguration.h"

@interface AWSURLSessionConfiguration ()

@property (nonatomic, copy) NSString *identifier;

@end

@implementation AWSURLSessionConfiguration

@synthesize identifier = _identifier;

+ (AWSURLSessionConfiguration *)defaultSessionConfiguration
{
	return [[self class] new];
}

+ (instancetype)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier
{
	AWSURLSessionConfiguration *configuration = [[self class] new];
	configuration.identifier = identifier;
	
	return configuration;
}

- (id)copyWithZone:(NSZone *)zone
{
	AWSURLSessionConfiguration *result = [[[self class] allocWithZone:zone] init];
	result.identifier = self.identifier;
	
	return result;
}

@end
