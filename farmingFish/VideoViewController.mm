//
//  VideoViewController.m
//  farmingFish
//
//  Created by apple on 16/7/23.
//  Copyright © 2016年 雨神 623240480@qq.com. All rights reserved.
//
#import "UIViewController+Extension.h"
#import "VideoViewController.h"
#import "UIColor+hexStr.h"
#import <UIColor+uiGradients/UIColor+uiGradients.h>
#import "hcnetsdk.h"
#import "DeviceInfo.h"
#import "VideoCollectionViewCell.h"
#import <Masonry/Masonry.h>
#import "IOSPlayM4.h"
#import "Preview.h"
#include <stdio.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/poll.h>
#include <net/if.h>
#include <map>
#import "JSONKit.h"
#import "SQMenuShowView.h"
#import "TouchView.h"
VideoViewController *g_pController = NULL;
@interface VideoViewController ()<UICollectionViewDelegate,UICollectionViewDataSource>{
    int layoutMode;//1 2 3 4
    int lastMode;
    
    CGRect Screen_bounds;
    
    int g_iStartChan;
    int g_iPreviewChanNum;
    int m_lUserID;
    BOOL m_bPreview;
    int m_lRealPlayID;
    TouchView  *m_multiView[MAX_VIEW_NUM];
    int    m_nPreviewPort;
    int singleSelectIndex;
    int sIndex;
}
@property(nonatomic,strong) NSDictionary *configParams;
@property(nonatomic,strong) UICollectionView *collectionView;
@property(nonatomic,strong) UIScrollView     *scrollView;
@property(nonatomic,strong) UIPageControl    *pageControl;
@property(nonatomic,strong) SQMenuShowView   *showView;
@property(nonatomic,assign) BOOL   isShow;
@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"我的视频";
    NSArray *arr=[[_videoInfo objectForKey:@"GetUserVideoInfoResult"] objectFromJSONString];
    if(arr!=nil&&[arr count]>0){
       self.configParams=arr[0];
    }
    [self navigationBarInit];
    
    [self viewControllerBGInit];
    
   
    
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"浏览模式" style: UIBarButtonItemStyleDone target:self action:@selector(popupView:)];
    
    
    
    g_pController=self;
    Screen_bounds=self.view.bounds;
    Screen_bounds.size.height=Screen_bounds.size.width-40;
   
    
    
    
    layoutMode=4;
    
    float width=(Screen_bounds.size.width-(layoutMode-1))/layoutMode;
    float height=(Screen_bounds.size.height-(layoutMode-1))/layoutMode;
    
    /*
     * UICollectionView layout
     */
    UICollectionViewFlowLayout *flowLayout=[[UICollectionViewFlowLayout alloc] init];
    //设置布局方向为垂直流布局
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    flowLayout.itemSize=CGSizeMake(width, height);
    
    flowLayout.minimumLineSpacing=1;
    flowLayout.minimumInteritemSpacing=1;
   
    
    self.collectionView=[[UICollectionView alloc] initWithFrame:CGRectMake(0, 64,Screen_bounds.size.width,Screen_bounds.size.height) collectionViewLayout:flowLayout];
    
    self.collectionView.backgroundColor=[UIColor whiteColor];
    self.collectionView.delegate=self;
    self.collectionView.dataSource=self;
    self.collectionView.layer.borderWidth=1;
    self.collectionView.layer.borderColor=[[UIColor whiteColor] CGColor];
    [self.collectionView setPagingEnabled:YES];
    
    
    [_collectionView registerNib:[UINib nibWithNibName:@"VideoCollectionViewCell" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"videoCell"];
    
    
    
    [self.view addSubview:_collectionView];

    
    for(int i=0;i<MAX_VIEW_NUM;i++){
        m_multiView[i]=[[TouchView alloc] initWithFrame:CGRectMake(0,0,0,0)];
        [m_multiView[i] setBackgroundColor:[UIColor blackColor]];
        [m_multiView[i] setTag:i];
        [m_multiView[i] setPtzDelegate:self];
    }
    
    
    
    [self scaleViewLayout];
    
    [self initPopupView];
   
}
/*
 * 初始化popupView
 */
-(void)initPopupView{
    self.showView=[[SQMenuShowView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.view.frame)-100-10, 64+5,100,0) items:@[@"1x1",@"2x2",@"3x3",@"4x4"] showPoint:CGPointMake(CGRectGetWidth(self.view.frame)-25,10)];
    __weak typeof(self) weakSelf=self;
    
    [_showView setSelectBlock:^(SQMenuShowView *view, NSInteger index) {
        weakSelf.isShow=NO;
        singleSelectIndex=-1;
        layoutMode=(index+1);
        [weakSelf layoutReload];
    }];
    
    _showView.sq_backGroundColor=[UIColor whiteColor];
    [self.view addSubview:_showView];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self dismissView];
}
-(void)dismissView{
    _isShow=NO;
    [self.showView dismissView];

}
-(void)poppupViewHideOrShow{
    _isShow= !_isShow;
    if(_isShow){
        [self.showView showView];
    }else{
        [self.showView dismissView];
    }
}
-(void)popupView:(id)sender{
    [self poppupViewHideOrShow];
}



-(void)viewWillAppear:(BOOL)animated{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         [self loginHCSystem];
         [self playVideo];
    });
    
}
-(void)viewWillDisappear:(BOOL)animated{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         [self closeVideo];
    });
}

-(void)scaleViewLayout{
    UIView *ptzview=[[UIView alloc] initWithFrame:CGRectMake(0,_collectionView.frame.origin.y+_collectionView.frame.size.height,Screen_bounds.size.width, 50)];
    

    float h_space1=(Screen_bounds.size.width-40*4)/5;
    NSArray *titles=@[@"上",@"下",@"左",@"右"];
    
    for (int i=0; i<4; i++) {
        
        UIButton *btn=[[UIButton alloc] initWithFrame:CGRectMake(h_space1*(i+1)+40*(i),(50-40)/2, 40, 40)];
        
        [btn setTitle:[NSString stringWithFormat:@"%@",titles[i]] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn setBackgroundColor:[UIColor purpleColor]];
        
        [btn setTag:(i+1)];
        [btn addTarget:self action:@selector(ptzMode:) forControlEvents:UIControlEventTouchDown];
        
        [btn addTarget:self action:@selector(ptzModeStop:) forControlEvents:UIControlEventTouchUpInside];
        
        [ptzview addSubview:btn];
    }
    
    [self.view addSubview:ptzview ];
    
    
}


-(void)ptzControl:(int)channel ptzDirect:(int)pd{
    int PTZ_DIRECT=PAN_AUTO;
    
    if(pd==1){
        PTZ_DIRECT=TILT_UP;
    }else if(pd==2){
        PTZ_DIRECT=TILT_DOWN;
    }else if (pd==3){
        PTZ_DIRECT=PAN_LEFT;
    }else if (pd==4){
        PTZ_DIRECT=PAN_RIGHT;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if(!NET_DVR_PTZControl_Other(m_lUserID, g_iStartChan+channel, PTZ_DIRECT, 0))
        {
            NSLog(@"start  failed with[%d]", NET_DVR_GetLastError());
        }
        else
        {
            NSLog(@"start  succ");
        }
        
        if(!NET_DVR_PTZControl_Other(m_lUserID, g_iStartChan+channel, PTZ_DIRECT, 1))
        {
            NSLog(@"stop  failed with[%d]", NET_DVR_GetLastError());
        }
        else
        {
            NSLog(@"stop  succ");
        }

    });
    
    

}

-(void)ptzModeStop:(UIButton *)sender{
    int mode=sender.tag;
    int PTZ_DIRECT=PAN_AUTO;
    
    if(mode==1){
        PTZ_DIRECT=TILT_UP;
    }else if(mode==2){
        PTZ_DIRECT=TILT_DOWN;
    }else if (mode==3){
        PTZ_DIRECT=PAN_LEFT;
    }else if (mode==4){
        PTZ_DIRECT=PAN_RIGHT;
    }
    
    
    if(!NET_DVR_PTZControl_Other(m_lUserID, g_iStartChan+singleSelectIndex, PTZ_DIRECT, 1))
    {
        NSLog(@"stop  failed with[%d]", NET_DVR_GetLastError());
    }
    else
    {
        NSLog(@"stop  succ");
    }

}
-(void)ptzMode:(UIButton *)sender{
    NSLog(@"singleSelectIndex %d",singleSelectIndex);
    int mode=sender.tag;
    int PTZ_DIRECT=PAN_AUTO;
    if(mode==1){
        PTZ_DIRECT=TILT_UP;
    }else if(mode==2){
        PTZ_DIRECT=TILT_DOWN;
    }else if (mode==3){
        PTZ_DIRECT=PAN_LEFT;
    }else if (mode==4){
        PTZ_DIRECT=PAN_RIGHT;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if(!NET_DVR_PTZControl_Other(m_lUserID, g_iStartChan+singleSelectIndex, PTZ_DIRECT, 0))
        {
            NSLog(@"start  failed with[%d]", NET_DVR_GetLastError());
        }
        else
        {
            NSLog(@"start  succ");
        }
    });
    
    
    
}




-(void)layoutReload{
    UICollectionViewFlowLayout *flowLayout=_collectionView.collectionViewLayout;
    float width=(Screen_bounds.size.width-(layoutMode-1))/layoutMode;
    float height=(Screen_bounds.size.height-(layoutMode-1))/layoutMode;
    flowLayout.itemSize=CGSizeMake(width, height);
    
    [_collectionView setCollectionViewLayout:flowLayout animated:YES];
    
    [_collectionView reloadData];
}


#pragma mark collectionView delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    
    return layoutMode*layoutMode;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    

    VideoCollectionViewCell *cell=[collectionView dequeueReusableCellWithReuseIdentifier:@"videoCell" forIndexPath:indexPath];
   
    if(singleSelectIndex>0){
         [m_multiView[singleSelectIndex] removeFromSuperview];
         [cell.videoView addSubview:m_multiView[singleSelectIndex]];
        [m_multiView[singleSelectIndex] mas_makeConstraints:^(MASConstraintMaker *make) {
            
            make.height.equalTo(@[cell.videoView.mas_height,m_multiView[singleSelectIndex].mas_height]);
            make.width.equalTo(@[cell.videoView.mas_width,m_multiView[singleSelectIndex].mas_width]);
            
            make.leading.equalTo(@[cell.videoView.mas_leading,m_multiView[singleSelectIndex].mas_leading]);
            
            make.top.equalTo(@[cell.videoView.mas_top,m_multiView[singleSelectIndex].mas_top]);
            
        }];
    }else{
         [m_multiView[indexPath.row] removeFromSuperview];
         [cell.videoView addSubview:m_multiView[indexPath.row]];
        [m_multiView[indexPath.row] mas_makeConstraints:^(MASConstraintMaker *make) {
            
            make.height.equalTo(@[cell.videoView.mas_height,m_multiView[indexPath.row].mas_height]);
            make.width.equalTo(@[cell.videoView.mas_width,m_multiView[indexPath.row].mas_width]);
            
            make.leading.equalTo(@[cell.videoView.mas_leading,m_multiView[indexPath.row].mas_leading]);
            
            make.top.equalTo(@[cell.videoView.mas_top,m_multiView[indexPath.row].mas_top]);
            
        }];
    }
    
    for(UIGestureRecognizer *gr in cell.videoView.gestureRecognizers){
        [cell.videoView removeGestureRecognizer:gr];
    }
    
    UITapGestureRecognizer *tapGR1=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectVideo:)];
    [tapGR1 setNumberOfTapsRequired:1];

    
    
    UITapGestureRecognizer *tapGR2=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(modeSwitch:)];
   
    
    [tapGR2 setNumberOfTapsRequired:2];
    
    cell.videoView.tag=indexPath.row;
    
    if(sIndex==indexPath.row){
        cell.layer.borderWidth=2;
        cell.layer.borderColor=[[UIColor yellowColor] CGColor];
        
    }else{
        cell.layer.borderWidth=0;
        
    }
    
    [cell.videoView setUserInteractionEnabled:YES];
    
    [cell.videoView addGestureRecognizer:tapGR1];
    [cell.videoView addGestureRecognizer:tapGR2];
   
    [tapGR1 requireGestureRecognizerToFail:tapGR2];
   

    return cell;
}
-(void)selectVideo:(UIGestureRecognizer *)gr{
    [self dismissView];
    int index=gr.view.tag;
    sIndex=index;
    
    [_collectionView reloadData];
}
-(void)modeSwitch:(UIGestureRecognizer *)gr{
    [self dismissView];
    int index=gr.view.tag;
    
    if(layoutMode!=1){
        lastMode=layoutMode;
        layoutMode=1;
        singleSelectIndex=index;
    }else{
        if(lastMode!=0){
            layoutMode=lastMode;
        }
        singleSelectIndex=-1;
    }
    [self layoutReload];

}

-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

-(void)loginHCSystem{
    m_lUserID=-1;
    g_iStartChan=0;
    g_iPreviewChanNum=0;
    
    NSArray *ipAndPortArr=[self domainIpAndPort];
    DeviceInfo *deviceInfo = [[DeviceInfo alloc] init];
    deviceInfo.chDeviceAddr = ipAndPortArr[0];
    deviceInfo.nDevicePort = [ipAndPortArr[1] intValue];
    
    
    
    deviceInfo.chLoginName = [_configParams objectForKey:@"F_UserName"];//账户名
    deviceInfo.chPassWord = [_configParams objectForKey:@"F_UserPwd"];;//密码
    
    // device login
    NET_DVR_DEVICEINFO_V30 logindeviceInfo = {0};
    
    // encode type
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    m_lUserID = NET_DVR_Login_V30((char*)[deviceInfo.chDeviceAddr UTF8String],
                                  deviceInfo.nDevicePort,
                                  (char*)[deviceInfo.chLoginName cStringUsingEncoding:enc],
                                  (char*)[deviceInfo.chPassWord UTF8String],
                                  &logindeviceInfo);
    
    printf("iP:%s\n", (char*)[deviceInfo.chDeviceAddr UTF8String]);
    printf("Port:%d\n", deviceInfo.nDevicePort);
    printf("UsrName:%s\n", (char*)[deviceInfo.chLoginName cStringUsingEncoding:enc]);
    printf("Password:%s\n", (char*)[deviceInfo.chPassWord UTF8String]);
   
    if(m_lUserID!=-1){
        if(logindeviceInfo.byChanNum > 0)
        {
            g_iStartChan = logindeviceInfo.byStartChan;
            g_iPreviewChanNum = logindeviceInfo.byChanNum;
        }
        else if(logindeviceInfo.byIPChanNum > 0)
        {
            g_iStartChan = logindeviceInfo.byStartDChan;
            g_iPreviewChanNum = logindeviceInfo.byIPChanNum + logindeviceInfo.byHighDChanNum * 256;
        }
 
        NSLog(@"g_iStartChan %d",g_iStartChan);
        NSLog(@"g_iPreviewChanNum %d",g_iPreviewChanNum);
        
        
       
        
    }
    
    
    
}
-(void)previewPlay:(int*)iPlayPort playView:(UIView *)playView
{
    m_nPreviewPort = *iPlayPort;
    int iRet = PlayM4_Play(*iPlayPort,(__bridge void *)playView);
    PlayM4_PlaySound(*iPlayPort);
    if (iRet != 1)
    {
        NSLog(@"PlayM4_Play fail");
        [self stopPreviewPlay:(iPlayPort)];
        return;
    }
}

- (void)stopPreviewPlay:(int*)iPlayPort
{
    PlayM4_StopSound();
    if (!PlayM4_Stop(*iPlayPort))
    {
        NSLog(@"PlayM4_Stop failed");
    }
    if(!PlayM4_CloseStream(*iPlayPort))
    {
        NSLog(@"PlayM4_CloseStream failed");
    }
    if (!PlayM4_FreePort(*iPlayPort))
    {
        NSLog(@"PlayM4_FreePort failed");
    }
    *iPlayPort = -1;
}

-(void)closeVideo{
    for(int i = 0; i < MAX_VIEW_NUM; i++)
    {
        stopPreview(i);
    }
    m_bPreview = false;

}

-(void)playVideo{
    NSLog(@"liveStreamBtnClicked");
    
    if(g_iPreviewChanNum > 0)
    {
        int iPreviewID[MAX_VIEW_NUM] = {0};
        for(int i = 0; i < MAX_VIEW_NUM; i++)
        {
            iPreviewID[i] = startPreview(m_lUserID, g_iStartChan, m_multiView[i], i);
        }
        m_lRealPlayID = iPreviewID[0];
        m_bPreview = true;

    }
}


/**获取动态ip port**/
-(NSArray *)domainIpAndPort{
    NSString *F_OutIPAddr=[_configParams objectForKey:@"F_OutIPAddr"];
    
    NSArray *params=[F_OutIPAddr componentsSeparatedByString:@"|"];
    
    NSString *ipAddr=params[0];
    NSString *nickname=params[1];
    
    
    BOOL bRet = NET_DVR_Init();
    if (!bRet)
    {
        NSLog(@"NET_DVR_Init failed");
    }

    
    NSArray *ipAndPortArr=nil;
    NET_DVR_QUERY_COUNTRYID_COND	struCountryIDCond = {0};
    NET_DVR_QUERY_COUNTRYID_RET		struCountryIDRet = {0};
    struCountryIDCond.wCountryID = 248;//China
    
    memcpy(struCountryIDCond.szSvrAddr, ipAddr.UTF8String, strlen(ipAddr.UTF8String));
    memcpy(struCountryIDCond.szClientVersion, "iOS NetSDK Demo", strlen("iOS NetSDK Demo"));
    if(NET_DVR_GetAddrInfoByServer(QUERYSVR_BY_COUNTRYID, &struCountryIDCond, sizeof(struCountryIDCond), &struCountryIDRet, sizeof(struCountryIDRet)))
    {
        NSLog(@"QUERYSVR_BY_COUNTRYID succ,resolve:%s", struCountryIDRet.szResolveSvrAddr);
    }
    else
    {
        LONG ERROR_CODE=NET_DVR_GetLastError();
        
        NSLog(@"QUERYSVR_BY_COUNTRYID failed:%s", NET_DVR_GetErrorMsg(&ERROR_CODE));
    }
    //follow code show how to get dvr/ipc address from the area resolve server by nickname or serial no.
    NET_DVR_QUERY_DDNS_COND	struDDNSCond = {0};
    NET_DVR_QUERY_DDNS_RET	struDDNSQueryRet = {0};
    NET_DVR_CHECK_DDNS_RET	struDDNSCheckRet = {0};
    memcpy(struDDNSCond.szClientVersion, "iOS NetSDK Fish", strlen("iOS NetSDK Fish"));
    memcpy(struDDNSCond.szResolveSvrAddr, struCountryIDRet.szResolveSvrAddr, strlen(struCountryIDRet.szResolveSvrAddr));
    memcpy(struDDNSCond.szDevNickName, nickname.UTF8String, strlen(nickname.UTF8String));//your dvr/ipc nickname
    if(NET_DVR_GetAddrInfoByServer(QUERYDEV_BY_NICKNAME_DDNS, &struDDNSCond, sizeof(struDDNSCond), &struDDNSQueryRet, sizeof(struDDNSQueryRet)))
    {
        NSLog(@"QUERYDEV_BY_NICKNAME_DDNS succ,ip[%s],sdk port[%d]:", struDDNSQueryRet.szDevIP, struDDNSQueryRet.wCmdPort);
        
        NSString *ipObj=[[NSString alloc] initWithUTF8String:struDDNSQueryRet.szDevIP];
        
        
        
        ipAndPortArr=@[ipObj,@(struDDNSQueryRet.wCmdPort)];
    }
    else
    {
        NSLog(@"QUERYDEV_BY_NICKNAME_DDNS failed:%d", NET_DVR_GetLastError());
    }
    
    //if you get the dvr/ipc address failed from the area reolve server,you can check the reason show as follow
    if(NET_DVR_GetAddrInfoByServer(CHECKDEV_BY_NICKNAME_DDNS, &struDDNSCond, sizeof(struDDNSCond), &struDDNSCheckRet, sizeof(struDDNSCheckRet)))
    {
        NSLog(@"CHECKDEV_BY_NICKNAME_DDNS succ,ip[%s], sdk port[%d], region[%d], status[%d]",struDDNSCheckRet.struQueryRet.szDevIP, struDDNSCheckRet.struQueryRet.wCmdPort, struDDNSCheckRet.wRegionID, struDDNSCheckRet.byDevStatus);
    }
    else
    {
        NSLog(@"CHECKDEV_BY_NICKNAME_DDNS failed[%d]", NET_DVR_GetLastError());
    }
    
    return ipAndPortArr;
    
}
 
 

@end
