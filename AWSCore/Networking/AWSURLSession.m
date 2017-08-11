//
//  AWSURLSession.m
//  AWSS3
//
//  Created by Vitaly Afanasyev on 8/7/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import "AWSURLSession.h"
#import <stdlib.h>

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

@property (readonly, retain) NSMutableDictionary<NSNumber *, AWSURLSessionTask *> *sessionTasksByIdentifier;
@property (readonly, retain) NSLock *modifyingTasksLock;
@property (assign) BOOL finishingTasksRequested;
@property (retain) NSOperationQueue *delegateQueue;
@property (nullable, retain) id <AWSURLSessionDelegate> delegate;
@property (copy) AWSURLSessionConfiguration *configuration;

@end

@interface AWSURLSessionTask ()<NSURLConnectionDelegate>

@property (assign) NSUInteger taskIdentifier;    /* an identifier for this task, assigned by and unique to the owning session */

@property (assign) id<AWSURLSessionTaskInternalDelegate> delegate;
@property (readonly, retain) NSURLConnection *connection;
@property (copy) NSURLResponse *response;
@property (assign) AWSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

@end

@interface AWSURLSessionDataTask ()

@property (assign) id<AWSURLSessionDataTaskInternalDelegate> delegate;

@end

@interface AWSURLSessionDownloadTask ()

@property (assign) id<AWSURLSessionDownloadTaskInternalDelegate> delegate;

@end

@implementation AWSURLSession

@synthesize sessionTasksByIdentifier = _sessionTasksByIdentifier;
@synthesize delegateQueue = _delegateQueue;
@synthesize modifyingTasksLock = _modifyingTasksLock;

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

- (NSMutableDictionary<NSNumber *, AWSURLSessionTask *> *)sessionTasksByIdentifier
{
	@synchronized (self)
	{
		if (_sessionTasksByIdentifier == nil)
		{
			_sessionTasksByIdentifier = [NSMutableDictionary new];
		}
	}
	return _sessionTasksByIdentifier;
}

- (NSLock *)modifyingTasksLock
{
	@synchronized (self)
	{
		if (_modifyingTasksLock == nil)
		{
			_modifyingTasksLock = [NSLock new];
		}
	}
	return _modifyingTasksLock;
}


- (void)getTasksWithCompletionHandler:(void (^)(NSArray<AWSURLSessionDataTask *> *dataTasks, NSArray<AWSURLSessionUploadTask *> *uploadTasks, NSArray<AWSURLSessionDownloadTask *> *downloadTasks))completionHandler
{
	
	NSMutableArray<AWSURLSessionDataTask *> *dataTasks = [NSMutableArray array];
	NSMutableArray<AWSURLSessionUploadTask *> *uploadTasks = [NSMutableArray array];
	NSMutableArray<AWSURLSessionDownloadTask *> *downloadTasks = [NSMutableArray array];
	
	[self.modifyingTasksLock lock];
	
	[self.sessionTasksByIdentifier enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, AWSURLSessionTask * _Nonnull task, BOOL * _Nonnull stop)
	{
		if ([task isKindOfClass:[AWSURLSessionDataTask class]])
		{
			[dataTasks addObject:(AWSURLSessionDataTask *)task];
		}
		else if ([task isKindOfClass:[AWSURLSessionDownloadTask class]])
		{
			[downloadTasks addObject:(AWSURLSessionDownloadTask *)task];
		}
		else if ([task isKindOfClass:[AWSURLSessionUploadTask class]])
		{
			[uploadTasks addObject:(AWSURLSessionUploadTask *)task];
		}
	}];
	
	[self.modifyingTasksLock unlock];
	
	completionHandler([dataTasks copy], [uploadTasks copy], [downloadTasks copy]);
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
		[self registerTask:result];
	}
	
	return result;
}

- (AWSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
{
	AWSURLSessionDownloadTask *result = [[AWSURLSessionDownloadTask alloc] initWithRequest:request];
	result.delegate = self;
	
	if (result != nil)
	{
		[self registerTask:result];
	}
	
	return result;
}

- (AWSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
{
	AWSURLSessionDataTask *result = [[AWSURLSessionDataTask alloc] initWithRequest:request];
	result.delegate = self;
	
	if (result != nil)
	{
		[self registerTask:result];
	}
	
	return result;
}

- (void)registerTask:(AWSURLSessionTask *)task
{
	[self.modifyingTasksLock lock];
	NSMutableDictionary *sessionTasksByIdentifier = self.sessionTasksByIdentifier;
	NSUInteger identifier = 0;
	
	do
    {
		identifier = arc4random();
	}
	while (sessionTasksByIdentifier[@(identifier)] != nil);
	
	task.taskIdentifier = identifier;
	
	self.sessionTasksByIdentifier[@(identifier)] = task;
	
	[self.modifyingTasksLock unlock];
}

- (void)unregisterTask:(AWSURLSessionTask *)task
{
	[self.modifyingTasksLock lock];
	
	[self.sessionTasksByIdentifier removeObjectForKey:@(task.taskIdentifier)];
	
	[self.modifyingTasksLock unlock];
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
	
	[self unregisterTask:sessionTask];
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
		_state = AWSURLSessionTaskStateSuspended;
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
	self.state = AWSURLSessionResponseCancel;
}

- (void)resume
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		NSRunLoop *runLoop = NSRunLoop.currentRunLoop;
		[self.connection scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
		[self.connection start];
		self.state = AWSURLSessionTaskStateRunning;
		
		while (self.state == AWSURLSessionTaskStateRunning)
		{
			[runLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
		}
	});
}

- (void)suspend
{
	
}

#pragma mark - NSURLConnectionDelegate

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
	return NO;
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	return YES;
}

- (nullable NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
	return nil;
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL
{
	self.state = AWSURLSessionTaskStateCompleted;
	[self.delegate task:self didCompleteWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.response = response;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	self.state = AWSURLSessionTaskStateCompleted;
	[self.delegate task:self didCompleteWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	self.state = AWSURLSessionTaskStateCompleted;
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
	[super connectionDidFinishDownloading:connection destinationURL:destinationURL];
	[self.delegate downloadTask:self didFinishDownloadingToURL:destinationURL];
}

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes
{
	[self.delegate downloadTask:self didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:expectedTotalBytes];
}

@end
