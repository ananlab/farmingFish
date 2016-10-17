//
//  ExpandControlView.m
//  farmingFish
//
//  Created by admin on 16/10/12.
//  Copyright © 2016年 雨神 623240480@qq.com. All rights reserved.
//

#import "ExpandControlView.h"

#import "MyExpandTableView.h"
#import "UIButton+BGColor.h"
#import "SocketService.h"
#import <MBProgressHUD/MBProgressHUD.h>
#define HEAD_HEIGHT 40

@interface ExpandControlView(){
   
}
@property(nonatomic,strong) RealDataLoadBlock block;

@end
@implementation ExpandControlView

-(instancetype)init{
    self=[super init];
    if(self){
       [self setUpViews];
     
    }
    NSLog(@"init...");
    return self;
}
-(instancetype)initWithFrame:(CGRect)frame{
    self=[super initWithFrame:frame];
    if(self){
       [self setUpViews];
    }
    NSLog(@"initWithFrame...");
    return self;
}
-(instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style{
    self=[super initWithFrame:frame style:style];
    if(self){
        [self setUpViews];
    }
    NSLog(@"initWithFrame...style ...");
    return self;
    
}
-(void)setUpViews{
    self.dataSource=self;
    self.delegate=self;
    

    [self setSeparatorStyle:(UITableViewCellSeparatorStyleNone)];
}


#pragma mark datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return [_collectorInfos count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    /*
     *  state expand 展开状态显示正常数据
     *        关闭状态显示0
     */
    if(![[_collectorInfos objectAtIndex:section] expandYN]){
        return 0;
    }else{
        return 1;
    }
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    /*
     * 显示子节点数据
     */
    YYCollectorInfo *collectorInfo=[self findSelectedCollectorInfo];
    DeviceControlTableView *devControlView;
    YYControlDataUITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell2"];
    if(cell==nil){
        cell=[[YYControlDataUITableViewCell alloc] initWithStyle:(UITableViewCellStyleDefault) reuseIdentifier:@"cell2"];
        [cell setBackgroundColor:[UIColor clearColor]];
        
        devControlView=[[DeviceControlTableView alloc] initWithFrame:CGRectMake(10,10, cell.frame.size.width-20, 0)];
        devControlView.layer.borderColor=[[UIColor colorWithWhite:1 alpha:0.1] CGColor];
        devControlView.separatorColor=[UIColor colorWithWhite:1 alpha:0.3];
        devControlView.separatorColor=[UIColor colorWithWhite:1 alpha:0.3];
        
        devControlView.layer.borderWidth=1;
        devControlView.layer.cornerRadius=2;
        [devControlView setBackgroundColor:[UIColor colorWithWhite:0.8 alpha:0.1]];
       
        [cell addSubview:devControlView];
         cell.controlDataTableView=devControlView;
    }
    devControlView=cell.controlDataTableView;
    
    if(devControlView!=nil){
        [devControlView setDeviceDatas:collectorInfo.electricsArr];
        [devControlView setRealStatus:collectorInfo.electricsStatus];
        
        [devControlView reloadData];
        
        CGRect frame=devControlView.frame;
        frame.size.height=[collectorInfo.electricsArr count]*50;
        [devControlView setFrame:frame];
        CGRect frameCell=cell.frame;
        frameCell.size.height=frame.size.height+20;
        [cell setFrame:frameCell];
    }
    
    return cell;
}


- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    /*
     *显示父节点数据
     */
    
    
    UIButton *backgroundView=[[UIButton alloc] initWithFrame:CGRectMake(0,0,tableView.frame.size.width, HEAD_HEIGHT)];
    
    [backgroundView setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [backgroundView setTag:section];
    [backgroundView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2] forState:(UIControlStateNormal)];
    [backgroundView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.1] forState:(UIControlStateHighlighted)];
    [backgroundView addTarget:self action:@selector(groupExpand:) forControlEvents:UIControlEventTouchUpInside];
    
    UIImageView *arrowImageView=[[UIImageView alloc] initWithFrame:CGRectMake(10,(HEAD_HEIGHT-9)/2,16,9)];
    
    
    
    if(![[_collectorInfos objectAtIndex:section] expandYN]){
        [arrowImageView setImage:[UIImage imageNamed:@"arrow_down"]];
    }else{
        [arrowImageView setImage:[UIImage imageNamed:@"arrow_up"]];
    }
    
    
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(70,0,250,HEAD_HEIGHT)];
    [label setTextAlignment:NSTextAlignmentLeft];
    [label setFont:[UIFont systemFontOfSize:16]];
    [label setTextColor:[UIColor colorWithWhite:0 alpha:0.5]];
    label.text=[[_collectorInfos objectAtIndex:section] CustomerNo];
    
    [backgroundView addSubview:arrowImageView];
    [backgroundView addSubview:label];
    return backgroundView;
}


-(void)reloadTableViewUI:(int)selectCourseIndex{
   
    for(int i=0;i<[_collectorInfos count];i++){
        YYCollectorInfo *collectorInfo=[_collectorInfos objectAtIndex:i];
        if(i==selectCourseIndex){
            if([collectorInfo expandYN]){
                [collectorInfo setExpandYN:NO];
            }else{
                [collectorInfo setExpandYN:YES];
            }
        }else{
            [collectorInfo setExpandYN:NO];
        }
    }
    [self reloadData];
    
}

-(void)findCollector:(NSString *)CustomerNo setStatus:(NSString *)status{
    YYCollectorInfo *_temp;
    
    for (YYCollectorInfo *collectorInfo in _collectorInfos) {
        if([collectorInfo.CustomerNo isEqualToString:CustomerNo]){
            _temp=collectorInfo;
            break;
        }
    }
    [_temp setElectricsStatus:status];
}

-(YYCollectorInfo *)findSelectedCollectorInfo{
    YYCollectorInfo *_temp;
    
    for (YYCollectorInfo *collectorInfo in _collectorInfos) {
        if(collectorInfo.expandYN==YES){
            _temp=collectorInfo;
            break;
        }
    }
    return _temp;
}


-(void)reloadChildData:(int)selectCourseIndex{
 
    YYCollectorInfo *collectorInfo=[_collectorInfos objectAtIndex:selectCourseIndex];
    
    if([[_collectorInfos objectAtIndex:selectCourseIndex] expandYN]){
        [[SocketService shareInstance] disconnect];
    }else{
        
        [[SocketService shareInstance] connect:collectorInfo.CustomerNo];
        [[SocketService shareInstance] setOnlineStatusBlock:^(BOOL onlineYN,NSString *customerNO) {
            
            if(onlineYN){
                //@"实时数据";
                NSLog(@"%@ online",customerNO);
            }else{
                //@"实时数据(离线)";
                NSLog(@"%@ offline",customerNO);
            }
            
        }];
        
        [[SocketService shareInstance] setStatusBlock:^(NSDictionary *dic) {
            
            NSLog(@"%@",dic);
            __block NSString *mStatus=nil;
            __block NSString *customNo=nil;
            [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSString*  _Nonnull obj, BOOL * _Nonnull stop) {
                
                 if([key isKindOfClass:[NSString class]]){
                    if([key isEqualToString:@"status"]){
                        mStatus=obj;
                    }else if ([key isEqualToString:@"customNo"]){
                        customNo=obj;
                    }
                }
                
            }];
            
            [self findCollector:customNo setStatus:mStatus];

            [self reloadData];
        }];

       
    }
    
    
    [self reloadTableViewUI:selectCourseIndex];
    
    
}




-(void)groupExpand:(UIButton *)sender{
    [self reloadChildData:sender.tag];
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return HEAD_HEIGHT;
}
-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return 0;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell=[self tableView:tableView cellForRowAtIndexPath:indexPath];
    
    return cell.frame.size.height;
}

@end

@implementation YYControlDataUITableViewCell


@end