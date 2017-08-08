//
//  AWSURLSession.m
//  AWSS3
//
//  Created by Vitaly Afanasyev on 8/7/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import "AWSURLSession.h"

const int64_t AWSURLSessionTransferSizeUnknown = -1LL;

@protocol AWSURLSessionTaskInternalDelegate <NSObject>

- (void)task:(AWSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error;
- (void)task:(AWSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent;

@end

@protocol AWSURLSessionDataTaskInternalDelegate <AWSURLSessionTaskInternalDelegate>

- (void)dataTask:(AWSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(AWSURLSessionResponseDisposition disposition))completionHandler;
- (void)dataTask:(AWSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;

@end


@protocol AWSURLSessionDownloadTaskInternalDelegate <AWSURLSessionTaskInternalDelegate>

- (void)downloadTask:(AWSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;
- (void)downloadTask:(AWSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;

@end


@interface AWSURLSession ()<AWSURLSessionTaskInternalDelegate, AWSURLSessionDataTaskInternalDelegate, AWSURLSessionDownloadTaskInternalDelegate>

@property (assign) BOOL finishingTasksRequested;
@property (retain) NSOperationQueue *delegateQueue;
@property (nullable, retain) id <AWSURLSessionDelegate> delegate;
@property (copy) AWSURLSessionConfiguration *configuration;
@property (retain, readonly) NSMutableArray<AWSURLSessionDataTask *> *dataTasks;
@property (retain, readonly) NSMutableArray<AWSURLSessionUploadTask *> *uploadTasks;
@property (retain, readonly) NSMutableArray<AWSURLSessionDownloadTask *> *downloadTasks;

@end

@interface AWSURLSessionTask ()<NSURLConnectionDelegate>

@property (assign) id<AWSURLSessionTaskInternalDelegate> delegate;
@property (readonly, retain) NSURLConnection *connection;
@property (copy) NSURLResponse *response;

- (instancetype)initWithRequest:(NSURLRequest *)request;

@end

@interface AWSURLSessionDataTask ()

@property (assign) id<AWSURLSessionDataTaskInternalDelegate> delegate;

@end

@interface AWSURLSessionDownloadTask ()

@property (assign) id<AWSURLSessionDownloadTaskInternalDelegate> delegate;

@end

@implementation AWSURLSession

@synthesize delegateQueue = _delegateQueue;
@synthesize downloadTasks = _downloadTasks;
@synthesize uploadTasks = _uploadTasks;
@synthesize dataTasks = _dataTasks;

+ (instancetype)sessionWithConfiguration:(AWSURLSessionConfiguration *)configuration delegate:(nullable id <AWSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue
{
	AWSURLSession *session = [[self class] new];
	session.delegateQueue = queue;
	session.configuration = configuration;
	session.delegate = delegate;
	
	return session;
}

- (NSOperationQueue *)delegateQueue
{
	@synchronized (self)
	{
		if (_delegateQueue == nil)
		{
			_delegateQueue = [NSOperationQueue new];
			_delegateQueue.maxConcurrentOperationCount = 1;
		}
	}
	
	return _delegateQueue;
}

- (NSMutableArray<AWSURLSessionDataTask *> *)dataTasks
{
	NSMutableArray<AWSURLSessionDataTask *> *result = nil;
	@synchronized (self)
	{
		if (_dataTasks == nil)
		{
			_dataTasks = [NSMutableArray new];
		}
		result = [_dataTasks mutableCopy];
	}
	return result;
}

- (NSMutableArray<AWSURLSessionUploadTask *> *)uploadTasks
{
	NSMutableArray<AWSURLSessionUploadTask *> *result = nil;
	@synchronized (self)
	{
		if (_uploadTasks == nil)
		{
			_uploadTasks = [NSMutableArray new];
		}
		result = [_uploadTasks mutableCopy];
	}
	return result;
}

- (NSMutableArray<AWSURLSessionDownloadTask *> *)downloadTasks
{
	NSMutableArray<AWSURLSessionDownloadTask *> *result = nil;
	@synchronized (self)
	{
		if (_downloadTasks == nil)
		{
			_downloadTasks = [NSMutableArray new];
		}
		result = [_downloadTasks mutableCopy];
	}
	return result;
}


- (void)setDelegateQueue:(NSOperationQueue *)delegateQueue
{
	@synchronized (self)
	{
		if (_delegateQueue != delegateQueue)
		{
			_delegateQueue = delegateQueue;
		}
	}
}

- (void)getTasksWithCompletionHandler:(void (^)(NSArray<AWSURLSessionDataTask *> *dataTasks, NSArray<AWSURLSessionUploadTask *> *uploadTasks, NSArray<AWSURLSessionDownloadTask *> *downloadTasks))completionHandler
{
	completionHandler([self.dataTasks copy], [self.uploadTasks copy], [self.downloadTasks copy]);
}

- (void)finishTasksAndInvalidate
{
	
}

- (AWSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;
{
	NSMutableURLRequest *mutableRequest = [request mutableCopy];
	mutableRequest.HTTPBodyStream = [NSInputStream inputStreamWithURL:fileURL];
	AWSURLSessionUploadTask *result = [[AWSURLSessionUploadTask alloc] initWithRequest:mutableRequest];
	result.delegate = self;
	
	if (result != nil)
	{
		@synchronized (self)
		{
			[self.uploadTasks addObject:result];
		}
	}
	
	return result;
}

- (AWSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
{
	AWSURLSessionDownloadTask *result = [[AWSURLSessionDownloadTask alloc] initWithRequest:request];
	result.delegate = self;
	
	if (result != nil)
	{
		@synchronized (self)
		{
			[self.downloadTasks addObject:result];
		}
	}
	
	return result;
}

- (AWSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
{
	AWSURLSessionDataTask *result = [[AWSURLSessionDataTask alloc] initWithRequest:request];
	result.delegate = self;
	
	if (result != nil)
	{
		@synchronized (self)
		{
			[self.dataTasks addObject:result];
		}
	}
	
	return result;
}

#pragma mark - AWSURLSessionTaskInternalDelegate

- (void)task:(AWSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error
{
	[self.delegateQueue addOperationWithBlock:^
	{
		if ([self.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)])
		{
			[(id<AWSURLSessionTaskDelegate>)self.delegate URLSession:self task:sessionTask didCompleteWithError:error];
		}
	}];
}

- (void)task:(AWSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent
{
	[self.delegateQueue addOperationWithBlock:^
	{
		if ([self.delegate respondsToSelector:@selector(URLSession:task:didSendBodyData:totalBytesSent:)])
		{
			[(id<AWSURLSessionTaskDelegate>)self.delegate URLSession:self task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent];
		}
	}];
}

#pragma mark - AWSURLSessionDataTaskInternalDelegate

- (void)dataTask:(AWSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(AWSURLSessionResponseDisposition disposition))completionHandler
{
	[self.delegateQueue addOperationWithBlock:^
	{
		if ([self.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)])
		{
			[(id<AWSURLSessionDataDelegate>)self.delegate URLSession:self dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
		}
	}];
}

- (void)dataTask:(AWSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	[self.delegateQueue addOperationWithBlock:^
	{
		if ([self.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)])
		{
			[(id<AWSURLSessionDataDelegate>)self.delegate URLSession:self dataTask:dataTask didReceiveData:data];
		}
	}];
}

#pragma mark - AWSURLSessionDownloadTaskInternalDelegate

- (void)downloadTask:(AWSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	[self.delegateQueue addOperationWithBlock:^
	{
		[(id<AWSURLSessionDownloadDelegate>)self.delegate URLSession:self downloadTask:downloadTask didFinishDownloadingToURL:location];
	}];
}

- (void)downloadTask:(AWSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
	[self.delegateQueue addOperationWithBlock:^
	{
		[(id<AWSURLSessionDownloadDelegate>)self.delegate URLSession:self downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
	}];
}

@end

@implementation AWSURLSessionTask

- (instancetype)initWithRequest:(NSURLRequest *)request
{
	self = [super init];
	
	if (self != nil)
	{
		_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	}
	
	return self;
}

- (NSURLRequest *)originalRequest
{
	return self.connection.originalRequest;
}

- (NSURLRequest *)currentRequest
{
	return self.connection.currentRequest;
}

- (void)cancel
{
	[self.connection cancel];
}

- (void)resume
{
	[self.connection start];
}

- (void)suspend
{
	
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.response = response;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.delegate task:self didCompleteWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.delegate task:self didCompleteWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	[self.delegate task:self didSendBodyData:bytesWritten totalBytesSent:totalBytesWritten];
}

@end

@implementation AWSURLSessionUploadTask

@end

@implementation AWSURLSessionDataTask

@dynamic delegate;

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[super connection:connection didReceiveResponse:response];
	
	[self.delegate dataTask:self didReceiveResponse:response completionHandler:^(AWSURLSessionResponseDisposition disposition)
	{
		// AWSURLSession currenlty supports only AWSURLSessionResponseAllow disposition value in completion handler
		NSParameterAssert(disposition == AWSURLSessionResponseAllow);
	}];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.delegate dataTask:self didReceiveData:data];
}

@end

@implementation AWSURLSessionDownloadTask

@dynamic delegate;

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL
{
	[self.delegate downloadTask:self didFinishDownloadingToURL:destinationURL];
}

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes
{
	[self.delegate downloadTask:self didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:expectedTotalBytes];
}

@end
