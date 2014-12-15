%%  load syncing data
dataFolder=uipickfiles;
dataFolder=dataFolder{1};
[bf2fluorIdx,fluorAll,bfAll]=YamlFlashAlign(dataFolder);

if exist([dataFolder filesep 'hiResData.mat'],'file')
    hiResData=load([dataFolder filesep 'hiResData']);
    hiResData=hiResData.dataAll;
else
    hiResData=highResTimeTraceAnalysisTriangle4(dataFolder,imSize(1),imSize(2));
end

hiResFlashTime=(hiResData.frameTime(hiResData.flashLoc));
bfFlashTime=bfAll.frameTime(bfAll.flashLoc);
fluorFlashTime=fluorAll.frameTime(fluorAll.flashLoc);
[~,Hi2bf]=flashTimeAlign2(hiResFlashTime,bfFlashTime);
flashDiff=hiResFlashTime(Hi2bf)-bfFlashTime;
flashDiff=flashDiff-min(flashDiff);
f_hiResTime=fit(hiResFlashTime(Hi2bf),bfFlashTime,'poly1','Weight',exp(-flashDiff.^2));

hiResData.frameTime=f_hiResTime(hiResData.frameTime);
hiResFlashTime=(hiResData.frameTime(hiResData.flashLoc));

[~,bf2fluor]=flashTimeAlign2(bfFlashTime,fluorFlashTime);

flashDiff=fluorFlashTime-bfFlashTime(bf2fluor);
flashDiff=flashDiff-min(flashDiff);

f_fluorTime=fit(fluorFlashTime,bfFlashTime(bf2fluor),'poly1','Weight',exp(-flashDiff.^2));

if f_fluorTime.p1<.1
    f_fluorTime.p1=1;
end


fluorAll.frameTime=f_fluorTime(fluorAll.frameTime);
fluorFlashTime=fluorAll.frameTime(fluorAll.flashLoc);
%%
bfIdxList=1:length(bfAll.frameTime);
fluorIdxList=1:length(fluorAll.frameTime);
bfIdxLookup=interp1(bfAll.frameTime,bfIdxList,hiResData.frameTime,'PCHIP');
fluorIdxLookup=interp1(fluorAll.frameTime,fluorIdxList,hiResData.frameTime,'linear');

[hiImageIdx,ib]=unique(hiResData.imageIdx);
hiResLookup=interp1(hiImageIdx,ib,1:length(hiResData.frameTime));

%%
firstFullFrame=find(~isnan(bfIdxLookup),1,'first');
firstFullFrame=max(firstFullFrame,find(~isnan(fluorIdxLookup),1,'first'));
Zall=hiResData.Z;
timeAll=hiResData.frameTime;
stackIdx=hiResData.stackIdx;
subFolderName='fiducials20141207';

hiResActivityFolder=[dataFolder filesep subFolderName filesep 'hiResActivityFolder3Dtest'];
hiResSegmentFolder=[dataFolder filesep subFolderName filesep  'hiResSegmentFolder3Dtest'];
lookupFolderX=[dataFolder filesep subFolderName filesep  'lookupFolderXtest'];
lookupFolderY=[dataFolder filesep subFolderName filesep  'lookupFolderYtest'];
metaFolder=[dataFolder filesep subFolderName filesep  'metaDataFolder3Dtest'];
hiResSegmentFolderRaw=[dataFolder filesep subFolderName filesep  'hiResSegmentFolder3Dtest_raw'];
hiResActivityFolderRaw=[dataFolder filesep subFolderName filesep  'hiResActivityFolder3Dtest_raw'];
hiResSegmentFolderS1=[dataFolder filesep subFolderName filesep  'hiResSegmentFolder3Dtest_S1'];
hiResActivityFolderS1=[dataFolder filesep subFolderName filesep  'hiResActivityFolder3Dtest_S1'];
lowResFolder=[dataFolder filesep subFolderName filesep  'lowResFluor'];
lowResBFFolder=[dataFolder filesep subFolderName filesep  'lowResBF'];

%%

options.thresh1=.03; %initial Threshold
options.hthresh=-.001; %threshold for trace of hessian.
options.minObjSize=140; 
options.maxObjSize=Inf;
options.watershedFilter=1;
options.filterSize=[10 10 3];
options.pad=9;
options.noise=1;
options.show=0;
options.maxSplit=1;
options.minSphericity=.55;
options.valleyRatio=.8;
options.scaleFactor=[1,1,6];
spikeBuffer=0;
meanSliceFiltLevel=3;

gaussianFilter=fspecial('gaussian',[30,30],5);
gaussianFilter=convnfft(gaussianFilter,permute(gausswin(6,2),[2,3,1]));
gaussianFilter=gaussianFilter/sum(gaussianFilter(:));


%%
mkdir([dataFolder filesep subFolderName filesep 'stackDataWhole'])
outputData=[];
outputData.centroids=[];
outputData.Rintensities=[];
outputData.Gintensities=[];
outputData.Volume=[];
outputData.time=[];
outputData.wormMask=[];
outputDat.zPlaneIdx=[];
outputData.zMax=[];
outputData.zMin=[];
output0=outputData;
overwriteFlag=0;
stackList=1:max(stackIdx)-1;

if ~overwriteFlag;
    d=dir([dataFolder filesep subFolderName filesep 'stackDataWhole' filesep 'stack*']);
    d={d.name}';
    oldIdx=cell2mat(cellfun(@(x) str2double(x(6:9)),d,'UniformOutput',false));
    stackList=stackList((~ismember(stackList,oldIdx)'));
end
groupSize=100;
%%
for iGroup=1:length(stackList)/groupSize

group=groupSize*(iGroup-1):groupSize*(iGroup);

group=group(group<length(stackList));
group=group(group>1);

subStackList=stackList(group);
outputData=repmat(output0,length(subStackList),1);

parfor i=1:length(group);

    try
        
        iStack=subStackList(i);
    tic    
        %%
    imName=['image' num2str(iStack,'%3.5d') '.tif'];
    matName=['image' num2str(iStack,'%3.5d') '.mat'];
%    imageIdx=find(stackIdx==iStack);
  %  imageIdx=imageIdx(spikeBuffer+1:end-spikeBuffer);
    metaData=load([metaFolder filesep matName]);
    metaData=metaData.metaData.metaData;
    
worm=stackLoad([hiResSegmentFolder filesep imName]);
%worm=pedistalSubtract(worm);
worm(isnan(worm))=0;
zPos=metaData.zVoltage;
time=metaData.time;
activity=stackLoad([hiResActivityFolder filesep imName]);
%activity=pedistalSubtract(activity);
activity(isnan(activity))=0;

%% do segmentation
% if ~overwriteFlag && exist([imFolder filesep 'stack' num2str(iStack,'%3.4d') 'data.mat'],'file');
% wormMask=load([imFolder filesep 'stack' num2str(iStack,'%3.4d') 'data.mat']);
% wormMask=wormMask.wormMask;
% wormMask=AreaFilter(wormMask>9,options.minObjSize,[],6);
% 
% else
    
    wormMask=WormSegmentHessian3d_rescale(worm,options);
    
%end
    %%
    %look up intensities on both channels
    wormLabelMask=bwlabeln(wormMask,6);
stats=regionprops(wormLabelMask,worm,'WeightedCentroid','Area','PixelIdxList');
centroids=reshape([stats.WeightedCentroid],3,[])';

%smooth out activity for interpolating, this is equivalent to expanding the
%ROI's. 
activity=convnfft(activity,gaussianFilter,'same');

activity=convnfft(activity,gaussianFilter,'same');
Rall=accumarray(wormLabelMask(wormLabelMask>0),worm(wormLabelMask>0),[],...
    @(x) {x});
Gall=accumarray(wormLabelMask(wormLabelMask>0),activity(wormLabelMask>0),[],...
    @(x) {x});

Rintensities=cellfun(@(x) trimmean(x,20), Rall,'uniformoutput',0);
Gintensities=cellfun(@(a,b) mean(a(b>max(b(:)/2))),Gall,Rall,'uniformoutput',0);
Rintensities=cell2mat(Rintensities);Gintensities=cell2mat(Gintensities);
Rmax=cell2mat(cellfun(@(x) max((x)),Rall,'uniformoutput',0));
Gmax=cell2mat(cellfun(@(x) max((x)),Gall,'uniformoutput',0));
    %interpolate Z properly and scale
    realTime=interp1(time,centroids(:,3)); %arb scaling for now
zPlaneIdx=centroids(:,3);
%[~,~,zPix]=cellfun(@(x) ind2sub(size(K),x),{stats.PixelIdxList}','Uniformoutput',false);
%zMax=cellfun(@(x) max(x), zPix);
%zMin=cellfun(@(x) min(x), zPix);

centroids(:,3)=50*(1+interp1(zPos,centroids(:,3))); %arb scaling for now
Volume=[stats.Area]';

%save outputs in unique file
 outputFile=[dataFolder filesep 'stackDataWhole' filesep 'stack' num2str(iStack,'%04d') 'data'];
outputData(i).centroids=centroids;
outputData(i).Rintensities=Rintensities;
outputData(i).Gintensities=Gintensities;
outputData(i).Rmax=Rmax;
outputData(i).Gmax=Gmax;
outputData(i).Volume=Volume;
outputData(i).time=time;
ouptutData(i).centroidTime=realTime;
outputData(i).wormMask=wormLabelMask;
outputData(i).zPlaneIdx=zPlaneIdx;
%outputData(i).zMax=zMax;
%outputData(i).zMin=zMin;
%parsavestruct(outputFile,outputData(i));
display(['Completed stack' num2str(iStack,'%04d') 'in ' num2str(toc) ' seconds']);

    catch ME
    display(['Error in stack' num2str(iStack,'%04d') 'in ' num2str(toc) ' seconds']);
    ME
    end
    
end
%%
for i=1:length(outputData);
    if ~isempty(outputData(i).centroids)
        iStack=subStackList(i);
        outputFile=[dataFolder filesep 'stackDataWhole' filesep 'stack' num2str(iStack,'%04d') 'data'];
parsavestruct(outputFile,outputData(i));
        display(['Saving' num2str(iStack,'%04d')]);

    end
end

end



%%

