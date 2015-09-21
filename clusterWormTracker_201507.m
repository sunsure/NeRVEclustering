function clusterWormTracker_201507(filePath,startIdx)
%made specifically for 1hr queue, can only do ~ 250 comparisons per hour
 
if nargin==0
    filePath=uipickfiles;
    startIdx=1;
    filePath=filePath{1};
end
load(filePath);
%%
 matchesPerSegment=175;

runIdxList=find(cellfun(@(x) ~isempty(x),{pointStats.stackIdx}));
presentN=length(runIdxList);
runIdxList=runIdxList(round(1:presentN/matchesPerSegment:presentN));
% presentIdx=cellfun(@(x) ~isempty(x),{pointStats.stackIdx},'uniform',0);
% presentIdx=find(cell2mat(presentIdx));
presentIdx=1:length(pointStats);
N=length(presentIdx);
param.dim=3;
param.good=2;
param.excessive=4;
param.quiet=1;
param.difficult=2.e4;
iIdxList=startIdx;%:startIdx+stepSize-1;
%%
for iIdx=iIdxList%length(TrackData)
    %%
    i=presentIdx(iIdx);
    outRange=1:N;%max(1,i-windowSearch):min(length(TrackData),i+windowSearch);
    TrackMatrixi=zeros(size(pointStats(i).straightPoints,1),length(runIdxList));
    DMatrixi=TrackMatrixi;
    transformedTest=cell(length(presentIdx),3);
    for runIdx=1:length(runIdxList)%outRange;
        %%
        j=runIdxList(runIdx);
        try
            T1=[pointStats(i).straightPoints pointStats(i).pointIdx];
            T2=[pointStats(j).straightPoints pointStats(j).pointIdx];
            T1length=size(pointStats(i).straightPoints ,1);
            T2length=size(pointStats(j).straightPoints ,1);
                    pointStats(i).regionLabel(pointStats(i).regionLabel==2)=1;
                    pointStats(j).regionLabel(pointStats(j).regionLabel==2)=1;
                                
            if ~isempty(T1) && ~isempty(T2)
                for regionId=0:1
%%
                    select1=ismember(pointStats(i).regionLabel,regionId) ...
                        & pointStats(i).Rintensities>40;
                    select2=ismember(pointStats(j).regionLabel,regionId) &...
                        pointStats(j).Rintensities>40;
                    T1temp=T1(select1,1:3);
                    T2temp=T2(select2,1:3);
                    if ~isempty(T2temp) && ~isempty(T1temp)
                        if size(T1temp,1)>1 && size(T2temp,1)>1
                            [Transformed_M, multilevel_ctrl_pts, multilevel_param] = ...
                                gmmreg_L2_multilevel_jn(T2temp,T1temp, 3, [20, 5, 1], ...
                                [0.0008, 0.0000008, 0.00000008],[0 0],...
                                [0.00001 0.0001 0.001],0);
                        else
                            Transformed_M=T2temp;
                            
                            
                        end
                        trackInput=[T1temp  T1temp find(select1) ones(size(T1temp(:,1))); ...
                            Transformed_M T2temp find(select2) 2*ones(size(Transformed_M(:,1)))];
                        TrackOut=nan;
                        counter=10;
                        while(all(isnan(TrackOut(:))))
                            TrackOut=trackJN(trackInput,counter,param);
                            counter=counter-1;
                        end
                        
                        transformedTest{runIdx,regionId+1}=TrackOut;

                        
                        TrackOut(:,1:3)=[];
                        TrackStats=round(TrackOut(:,4:end));
                        TrackedIDs=TrackStats([1;diff(TrackStats(:,3))]==0,end);
                        TrackStats=TrackStats(ismember(TrackStats(:,end),TrackedIDs),:);
                        track1=TrackStats(1:2:end,1);
                        track2=TrackStats(2:2:end,1);
                        TrackMatrixi(track1,runIdx-outRange(1)+1)=track2;
                    end
                end
                
                select1= find(pointStats(i).Rintensities>40);
                select2=find(pointStats(j).Rintensities>40);
             %   T1temp=T1(select1,1:3);
              %  T2temp=T2(select2,1:3);
                
                matchedIdx=find( TrackMatrixi(:,runIdx-outRange(1)+1));
                
                matchedPairs=[matchedIdx, TrackMatrixi(matchedIdx,runIdx-outRange(1)+1)];
                T1matched=T1(matchedPairs(:,1),:);
                T2matched=T2(matchedPairs(:,2),:);
                unmatched1Idx=select1(~ismember(select1,matchedPairs(:,1)));
                unmatched2Idx=select2(~ismember(select2,matchedPairs(:,2)));
                T1unmatched=T1(unmatched1Idx,:);
                T2unmatched=T2(unmatched2Idx,:);
                
%                 scatter3(T1unmatched(:,1),T1unmatched(:,2),T1unmatched(:,3));
% axis equal
% hold on
% scatter3(T2unmatched(:,1),T2unmatched(:,2),T2unmatched(:,3));
% scatter3(T1unmatchedWarped(:,1),T1unmatchedWarped(:,2),T1unmatchedWarped(:,3),'x');
%      

                if ~isempty(matchedPairs) && ~isempty(unmatched1Idx)  && ~isempty(unmatched2Idx)
                    [T1unmatchedWarped] = tpswarp3points(T1matched(:,1:3), ...
                        T2matched(:,1:3),T1unmatched(:,1:3));
                    
                    
                    trackInput=[T1unmatchedWarped T1(unmatched1Idx,4) ones(size(T1unmatchedWarped(:,1))); ...
                        T2unmatched 2*ones(size(T2unmatched(:,1)))];
                    
                    counter=10;
                    TrackOut=nan;
                    while(all(isnan(TrackOut(:))))
                        TrackOut=trackJN(trackInput,counter,param);
                        counter=counter-1;
                    end
                    
                    TrackStats=round(TrackOut(:,4:end));
                    TrackedIDs=TrackStats([1;diff(TrackStats(:,3))]==0,end);
                    TrackStats=TrackStats(ismember(TrackStats(:,end),TrackedIDs),:);
                    track1=TrackStats(1:2:end,1);
                    track2=TrackStats(2:2:end,1);
                    TrackMatrixi(track1,runIdx-outRange(1)+1)=track2;
                 matchedIdx=find( TrackMatrixi(:,runIdx-outRange(1)+1));
                matchedPairs=[matchedIdx, TrackMatrixi(matchedIdx,runIdx-outRange(1)+1)];
                end
                
presentIJ=TrackMatrixi(:,runIdx-outRange(1)+1)>0;
points1=pointStats(i).straightPoints(presentIJ,:);
points2=pointStats(j).straightPoints(TrackMatrixi(presentIJ,runIdx-outRange(1)+1)>0,:);
pointdistances=sqrt(sum((points1-points2).^2,2));
DMatrixi(presentIJ,runIdx-outRange(1)+1)=pointdistances;
            end
        catch ME
            ME
        end
        
    end
    if isempty(TrackMatrixi)
        TrackMatrixi=[];
    end
    
    outputName=fileparts(filePath);
    outputName=[outputName filesep 'trackMatrix' num2str(iIdx,'%3.5d')];
    save(outputName,'TrackMatrixi','DMatrixi');
end
