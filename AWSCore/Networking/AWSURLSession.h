//
//  AWSURLSession.h
//  AWSS3
//
//  Created by Vitaly Afanasyev on 8/7/17.
//  Copyright © 2017 Amazon Web Services. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const int64_t AWSURLSessionTransferSizeUnknown;    /* -1LL */

@protocol AWSURLSessionDelegate;
@class AWSURLSessionConfiguration;
@class AWSURLSessionUploadTask;
@class AWSURLSessionDownloadTask;
@class AWSURLSessionDataTask;
@class AWSURLSessionTask;

typedef NS_ENUM(NSInteger, AWSURLSessionResponseDisposition) {
	AWSURLSessionResponseCancel = 0,                                      /* Cancel the load, this is the same as -[task cancel] */
	AWSURLSessionResponseAllow = 1,                                       /* Allow the load to continue */
	AWSURLSessionResponseBecomeDownload = 2,                              /* Turn this request into a download */
	AWSURLSessionResponseBecomeStream NS_ENUM_AVAILABLE(10_11, 9_0) = 3,  /* Turn this task into a stream task */
};

@interface AWSURLSession : NSObject

@property (readonly, retain) NSOperationQueue *delegateQueue;
@property (nullable, readonly, retain) id <AWSURLSessionDelegate> delegate;
@property (readonly, copy) AWSURLSessionConfiguration *configuration;

+ (instancetype)sessionWithConfiguration:(AWSURLSessionConfiguration *)configuration delegate:(nullable id <AWSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue;

/* Creates an upload task with the given request.  The body of the request will be created from the file referenced by fileURL */
- (AWSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;

/* Creates a download task with the given request. */
- (AWSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;

/* Creates a data task with the given request.  The request may have a body stream. */
- (AWSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;

- (void)getTasksWithCompletionHandler:(void (^)(NSArray<AWSURLSessionDataTask *> *dataTasks, NSArray<AWSURLSessionUploadTask *> *uploadTasks, NSArray<AWSURLSessionDownloadTask *> *downloadTasks))completionHandler; /* invokes completionHandler with outstanding data, upload and download tasks. */

- (void)finishTasksAndInvalidate;

@end

@protocol AWSURLSessionDelegate <NSObject>

@end

@interface AWSURLSessionTask : NSObject

@property (readonly) NSUInteger taskIdentifier;    /* an identifier for this task, assigned by and unique to the owning session */
@property (nullable, readonly, copy) NSURLResponse *response;         /* may be nil if no response has been received */
@property (nullable, readonly, copy) NSURLRequest  *originalRequest;  /* may be nil if this is a stream task */
@property (nullable, readonly, copy) NSURLRequest  *currentRequest;   /* may differ from originalRequest due to http server redirection */

- (void)suspend;
- (void)resume;
- (void)cancel;

@end

@interface AWSURLSessionDataTask : AWSURLSessionTask

@end

@interface AWSURLSessionUploadTask : AWSURLSessionTask

@end

@interface AWSURLSessionDownloadTask : AWSURLSessionTask

@end

@protocol AWSURLSessionTaskDelegate <AWSURLSessionDelegate>

@optional
- (void)URLSession:(AWSURLSession *)session task:(AWSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error;
- (void)URLSession:(AWSURLSession *)session task:(AWSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent;

@end

@protocol AWSURLSessionDataDelegate <AWSURLSessionTaskDelegate>

@optional
- (void)URLSession:(AWSURLSession *)session dataTask:(AWSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(AWSURLSessionResponseDisposition disposition))completionHandler;

- (void)URLSession:(AWSURLSession *)session dataTask:(AWSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;

@end

@protocol AWSURLSessionDownloadDelegate <AWSURLSessionTaskDelegate>

- (void)URLSession:(AWSURLSession *)session downloadTask:(AWSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;

@optional
- (void)URLSession:(AWSURLSession *)session downloadTask:(AWSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;

@end

NS_ASSUME_NONNULL_END
