//
//  AWSJSONSerialization.m
//  AWSCore
//
//  Created by Vitaly Afanasyev on 8/8/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import "AWSJSONSerialization.h"
#import "AWSJSONExtensions.h"

@implementation AWSJSONSerialization

+ (NSArray *)JSONCompatibleClasses
{
	return @[[NSString class], [NSNumber class], [NSArray class], [NSDictionary class]];
}

+ (nullable NSData *)dataWithJSONObject:(id)obj options:(AWSJSONWritingOptions)opt error:(NSError **)error
{
	NSData *result = nil;
	
	if ([[self JSONCompatibleClasses] containsObject:[obj class]])
	{
		NSString *JSONString = [obj JSONString];
		if (JSONString != nil)
		{
			result = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	
	return result;
}

+ (BOOL)isValidJSONObject:(id)obj
{
	return [[self JSONCompatibleClasses] containsObject:[obj class]] && [obj JSONString] != nil;
}

+ (nullable id)JSONObjectWithData:(NSData *)data options:(AWSJSONWritingOptions)opt error:(NSError **)error
{
	id result = nil;
	
	NSString *JSONString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (JSONString != nil)
	{
		result = [NSDictionary dictionaryWithJSONString:JSONString];
		
		if (result == nil)
		{
			result = [NSArray arrayWithJSONString:JSONString];
		}
	}
	
	return result;
}

@end

