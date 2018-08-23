//
//  ViewController.m
//  SNSURLConnection
//
//  Created by 李泽平 on 2018/8/22.
//  Copyright © 2018年 李泽平. All rights reserved.
//

/** 问题：
 1.没有下载进度，会影响用户体验
 2.内存偏高，有一个最大峰值
 3.数据在内存中，下载后一次性写入磁盘，文件大的时候会崩掉
 
 NSURLConnection
    - 从iOS2.0开始就存在
    - sendAsynchronousRequest 异步加载 在iOS5.0才有的到iOS9.0就被弃用，iOS5之前，是通过代理来实现网络开发的！！！
    - 开发简单的网络请求还是比较方便的，直接用异步方法！
    - 开发复杂的网络请求，步骤非常繁琐！
 
 NSURLConnectionDownloadDelegate    千万不要用！！！专门针对杂志的下载提供的接口
 如果在开发中使用 NSURLConnectionDownloadDelegate 下载，能够监听下载进度，但是无法拿到下载文件！
 Newsstand Kit’s    专门用来做杂志！！！
 
 */


#import "ViewController.h"

@interface ViewController ()<NSURLConnectionDataDelegate>

//下载文件的总大小
@property (nonatomic, assign) long long expectedContentLength;

//已下载文件的大小
@property (nonatomic, assign) long long dataSize;

//保存路径
@property (nonatomic, strong) NSString *filePath;

//输出流
@property (nonatomic, strong) NSOutputStream *stream;


@property (nonatomic, assign) CFRunLoopRef downLoadRunLoop;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self demo1];
}

////没有监听进度，不是实时写入的请求
//- (void)demo0{
//    NSString *str = @"https://music.163.com/api/osx/download/latest";
//    //    str = [str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];   str中有中文时使用，需要转码，不然nsurl会为nil
//    
//    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:str]];
//    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
//        [data writeToFile:@"/Users/lizeping/Desktop/测试数据/aaa.wmv" atomically:YES];
//    }];
//}


//有监听进度，实时写入的请求
/**
 在代理方法中实现
 1.下载进度---请求头中文件的总大小，然后接收服务器中的数据并相加，并实时除
 2.保存文件
    - 保存完成写入磁盘 这种方式并没有解决问题，与上面的效果相同，还是存在内存问题！
    - 边下载边写入
 */
- (void)demo1{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *str = @"https://github.com/chunnilzp/StudyCoreAnimation/archive/master.zip";
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:str]];

        //For the connection to work correctly, the calling thread’s run loop must be operating in the default run loop mode.
        //为了保证连接的正常工作，调用线程的RunLoop 必须运行在默认的运行循环模式下！！
        NSURLConnection *con = [NSURLConnection connectionWithRequest:request delegate:self];
        [con setDelegateQueue:[[NSOperationQueue alloc] init]];
        [con start];
        
        /*
         CoreFoundation 框架 CFRunLoopRef
         
         CFRunLoopStop 停止指定的RunLoop
         CFRunLoopGetCurrent() 拿到当前的RunLoop
         CFRunLoopRun() 启动当前的Runloop
         */
        
        self.downLoadRunLoop = CFRunLoopGetCurrent();
        CFRunLoopRun();
    });
}

#pragma mark - NSURLConnectionDataDelegate
//1.接受到服务器的相应   状态行&&响应头  -做接收文件前的准备工作
/** NSURLResponse中的属性
    expectedContentLength 文件大小
    suggestedFilename 文件名称
 */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    //记录文件总大小
    self.expectedContentLength = response.expectedContentLength;
    self.dataSize = 0;
    
    //生成保存路径
    self.filePath = [NSString stringWithFormat:@"/Users/lizeping/Desktop/测试数据/%@", response.suggestedFilename];
    
    //删除文件 removeItemAtPath如果文件存在就会直接删除，如果不存在就什么都不做！
    [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
    
    //创建输出流 已追加的方式打开文件流
    self.stream = [[NSOutputStream alloc] initToFileAtPath:self.filePath append:YES];
    [self.stream open];
}

//2.接收到服务器的数据,可能被调用很多次
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    //计算下载进度
    self.dataSize += [data length];
    float progress = (float)self.dataSize/self.expectedContentLength;
    NSLog(@"当前的进度：%f", progress);
    
    //边下边写入
//    //1.NSFileHandle 解决了内存峰值的问题
//    [self writeFileData:data];
    
    //2.NSOutputStream 输出流
    /**
     uint8_t
     */
    [self.stream write:data.bytes maxLength:data.length];
}

//3.所有的数据加载完毕  所有数据都传输完毕后的一个通知
- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NSLog(@"完成");
    //关闭文件流
    [self.stream close];
//    self.finish = YES;
    CFRunLoopStop(self.downLoadRunLoop);
}

//4.下载失败或错误
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
//    self.finish = YES;
    CFRunLoopStop(self.downLoadRunLoop);
}


- (void)writeFileData:(NSData *)data{
    /**
     NSFileManager：主要功能，创建目录，检查目录是否存在，遍历目录，删除文件。 针对文件操作！！相当于文件管理器
     NSFileHandle：文件"句柄"，理解为文件处理（Handle意味着对前面单词的操作）。
                   主要功能，就是对同一个文进行二进制的读和写！
     */
    //注意：fp中的p是指指针！！如果文件不存在，fp在实例化的结果是空的。
    NSFileHandle *fp = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    //判断文件是否存在,如果文件不存在，先把文件写入磁盘
    if (fp == nil) {
        [data writeToFile:self.filePath atomically:YES];
    }else{
        //将文件指针移动到文件的末尾
        [fp seekToEndOfFile];
        //在文件指针的地方写入文件
        [fp writeData:data];
        //在C语言的开发中，凡是涉及到文件的读写，都会有打开和关闭的操作
        [fp closeFile];
    }
    
}

@end
