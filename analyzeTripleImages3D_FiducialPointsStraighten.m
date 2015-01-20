%%analyzes triple images with just the centerline from the low mag data



Ztype='traingle';
imSize=[1200,600];
row=imSize(1);
col=imSize(2);
nPix=row*col;
%%  load syncing data
dataFolder=uipickfiles;
dataFolder=dataFolder{1};

%% algin all videos,    CHECK Z2IMAGEIDXOFFSET
[bfAll,fluorAll,hiResData]=tripleFlashAlign(dataFolder,imSize);




%% load Fiducials file
fiducialFile=dir([dataFolder filesep '*iducial*']);
fiducialFile={fiducialFile.name}';
if length(fiducialFile)~=1
        display('Select model file');

    fiducialFile=uipickfiles('FilterSpec',dataFolder);
    fiducialFile=load(fiducialFile{1});
    fiducialPoints=fiducialFile.fiducialPoints;
    z2ImageIdxOffset=fiducialFile.timeOffset;
else
    fiducialFile=load([dataFolder filesep fiducialFile{1}]);
    fiducialPoints=fiducialFile.fiducialPoints;
        z2ImageIdxOffset=fiducialFile.timeOffset;
    z2ImageIdxOffset=fiducialFile.timeOffset;

end

%% load alignment data

display('Select Low Res Alignment')
lowResFluor2BF=uipickfiles('FilterSpec','Y:\CommunalCode\3dbrain\registration');
lowResFluor2BF=load(lowResFluor2BF{1});
lowResBF2FluorT=invert(lowResFluor2BF.t_concord);


display('Select Hi to Low Fluor Res Alignment')
Hi2LowResF=uipickfiles('FilterSpec','Y:\CommunalCode\3dbrain\registration');
Hi2LowResF=load(Hi2LowResF{1});


% display('Select Hi to Low Res Alignment')
% 
% Hi2LowRes=uipickfiles('FilterSpec','Y:\CommunalCode\3dbrain\registration');
% Hi2LowRes=load(Hi2LowRes{1});
% t_concord = fitgeotrans(Hi2LowRes.Sall,Hi2LowRes.Aall,'projective');
 display('Select Hi Res Alignment')

S2AHiRes=uipickfiles('FilterSpec','Y:\CommunalCode\3dbrain\registration');
S2AHiRes=load(S2AHiRes{1});
rect1=S2AHiRes.rect1;
rect2=S2AHiRes.rect2;

%% load background image
try
    backgroundImageFile=dir([dataFolder filesep '*backgroundImage*']);
    if isempty(backgroundImageFile) || length(backgroundImageFile)>1
        display('Select Background Mat File')
        backgroundImageFile=uipickfiles('FilterSpec',dataFolder);
        backgroundImageFile=backgroundImageFile{1};
    else
        backgroundImageFile=[dataFolder filesep backgroundImageFile.name];
    end
    backgroundImage=load(backgroundImageFile);
    backgroundImage=backgroundImage.backgroundImage;
catch
    backgroundImage=0;
end
%%
load([dataFolder filesep 'refStackStraight.mat'])

refstack=normalizeRange(refstack);
maxRef=max(pedistalSubtract(refstack),[],3);
maxRef=normalizeRange(maxRef);
maxRef(isnan(maxRef))=0;
%% prep vidobj for avi files and .dat file

%search in dataFolder for avi's without the HUDS, one with the fluor and
%one without.
aviFiles=dir([dataFolder filesep '*.avi']);
aviFiles={aviFiles.name}';
aviFiles=aviFiles(cellfun(@(x) isempty(strfind(x,'HUDS')),aviFiles));
if length(aviFiles)==2
    aviFluorIdx=cellfun(@(x) ~isempty(strfind(x,'fluor')),aviFiles);
    behaviorMovie=[dataFolder filesep aviFiles{~aviFluorIdx}];
    fluorMovie=[dataFolder filesep aviFiles{aviFluorIdx}];
else
    display('Select avi files, behavior and then low mag fluor');
    movies=uipickfiles('FilterSpec',dataFolder);
    behaviorMovie=movies{1};
    fluorMovie=movies{2};
end

behaviorVidObj = VideoReader(behaviorMovie);
fluorVidObj= VideoReader(fluorMovie);

Fid=fopen([dataFolder filesep 'sCMOS_Frames_U16_1024x1024.dat']);

%% make lookup tables for indices
bfIdxList=1:length(bfAll.frameTime);
fluorIdxList=1:length(fluorAll.frameTime);
bfIdxLookup=interp1(bfAll.frameTime,bfIdxList,hiResData.frameTime,'linear');
fluorIdxLookup=interp1(fluorAll.frameTime,fluorIdxList,hiResData.frameTime,'linear');

[hiImageIdx,ib]=unique(hiResData.imageIdx);
hiResLookup=interp1(hiImageIdx,ib,1:length(hiResData.frameTime));


firstFullFrame=find(~isnan(bfIdxLookup),1,'first');
firstFullFrame=max(firstFullFrame,find(~isnan(fluorIdxLookup),1,'first'));

%%
stretchSize=25;
%lowResFolder=[dataFolder filesep 'lowResFolder'];
hiResActivityFolder=[dataFolder filesep 'fiducials' filesep 'hiResActivityFolder3Dtest'];
hiResSegmentFolder=[dataFolder filesep 'fiducials' filesep  'hiResSegmentFolder3Dtest'];
lookupFolderX=[dataFolder filesep 'fiducials' filesep  'lookupFolderXtest'];
lookupFolderY=[dataFolder filesep 'fiducials' filesep  'lookupFolderYtest'];
metaFolder=[dataFolder filesep 'fiducials' filesep  'metaDataFolder3Dtest'];
hiResSegmentFolderRaw=[dataFolder filesep 'fiducials' filesep  'hiResSegmentFolder3Dtest_raw'];
hiResActivityFolderRaw=[dataFolder filesep 'fiducials' filesep  'hiResActivityFolder3Dtest_raw'];
hiResSegmentFolderS1=[dataFolder filesep 'fiducials' filesep  'hiResSegmentFolder3Dtest_S1'];
hiResActivityFolderS1=[dataFolder filesep 'fiducials' filesep  'hiResActivityFolder3Dtest_S1'];
lowResFolder=[dataFolder filesep 'fiducials' filesep  'lowResFluor'];
lowResBFFolder=[dataFolder filesep 'fiducials' filesep  'lowResBF'];
mkdir(metaFolder);
mkdir(hiResActivityFolder);
mkdir(hiResSegmentFolder);
mkdir(lookupFolderX);
mkdir(lookupFolderY);
mkdir(hiResSegmentFolderRaw);
mkdir(hiResSegmentFolderS1);
mkdir(hiResActivityFolderRaw);
mkdir(hiResActivityFolderS1);
mkdir(lowResFolder);
mkdir(lowResBFFolder);

frames=1750:length(hiResData.frameTime); %start 1750, 12000 good too, 13000 for 3d
frames(ismember(frames,hiResData.flashLoc))=[];
movieFlag=0;
plotFlag=0;
saveFlag=1;
lookupSave=1;
imH=NaN(1,4);
lineH=NaN(1,4);
Ralign=2;
if movieFlag
    plotFlag=1;
    vidOut=VideoWriter([dataFolder filesep 'HiMagOnly.avi']);
    vidOut.FrameRate=20;
    
    open(vidOut);
end
spikeBuffer=0;
meanSliceFiltLevel=4;
yWindow=300;
xWindow=300;
hiResCorrection=[0,0];
splitFlag=0;
stackIdx=hiResData.stackIdx;

gaussianKernal=fspecial('gaussian', 80,20);
gaussianFilter=fspecial('gaussian',[100,100],30);
gaussianFilter=convnfft(gaussianFilter,permute(gausswin(10,3),[2,3,1]));

stackIdx2=interp1(stackIdx,hiResLookup);
Zlookup=interp1(hiResData.Z,hiResLookup);
timeLookup=interp1(hiResData.frameTime,hiResLookup);

%%  
Options.Registration='Affine';
  Options.Similarity='p';
  Options.MaxRef=20;
Options.Verbose=0;
Options.SigmaFluid=12;

%%
%progressbar(0,0)
interpMethod.method='nearest';
interpMethod.radius=40;
groupSize=80;% best to use factor of 8

%set up master fiducials

% masterFIdx=15;
% masterFiducials=fiducialPoints{masterFIdx};
% imageFIdx=z2ImageIdxOffset+find(stackIdx==masterFIdx);
% fiducialZ=round(interp1(imageFIdx+(1:length(imageFIdx))'*.0001,1:length(imageFIdx),cell2mat(masterFiducials(:,4))));
% fiducialIdx=find(cell2mat((cellfun(@(x) ~isempty(x),masterFiducials(:,1),'uniformoutput',0))));
% masterDirection=corr2([masterFiducials{:,3}]', [masterFiducials{:,4}]')>0;
% masterFiducials=[cell2mat(masterFiducials(:,1:2)) fiducialZ];
% masterFiducials=masterFiducials(fiducialIdx,:);

%%
hasPoints=cellfun(@(x) ~isempty(x{1}), fiducialPoints,'uniformoutput',0);
hasPoints=find(cell2mat(hasPoints));

for iGroup=1:ceil(length(hasPoints)/groupSize)
metaData=[];
metaData.metaData=[];
group=groupSize*(iGroup-1):groupSize*(iGroup);

group=group(group<length(hasPoints));
group=group(group>0);

metaData=repmat(metaData,1,length(group));

parfor i=1:length(group);
    iStack=hasPoints(group(i));
    
    try
        %%
        tic
        imageIdx=find(stackIdx==iStack);
        imageIdx=imageIdx(ismember(imageIdx,hiResData.imageIdx));
        imageIdx=imageIdx(spikeBuffer+1:end-spikeBuffer);
        worm=[];
        zPos=Zlookup(imageIdx);
        time=timeLookup(imageIdx);
        zPos=hiResData.Z(imageIdx);
        time=hiResData.frameTime(imageIdx);
        fluorIdxStack=fluorIdxLookup(imageIdx);
        maxXAll=[];maxYAll=[];
        activity=[];
        rawStack=[];
        highResInterpStack2=[];
        lowResFluorHiInterpStack=[];
        highResInterpStack=[];
        hiResMean=[];
        newYHiFout=[];
        lowResFluorStack=[];
        highResActivityInterpStack=[];
        newXHiFout=[];
        segmentStack=[];
        activityStack=[];
        Cout=[];
        
        Fid=fopen([dataFolder filesep 'sCMOS_Frames_U16_1024x1024.dat']);
        
        %%
%         CLIdx=round(bfIdxLookup(imageIdx));
%         [xCLsearch,yCLsearch]=meshgrid(1:100,CLIdx);
%                CLcurrent=cat(3,interp2(squeeze(centerline(:,1,:))',xCLsearch,yCLsearch),...
%                 interp2(squeeze(centerline(:,2,:))',xCLsearch,yCLsearch));
%             CLcurrent=squeeze(trimmean(CLcurrent,20,1));
%            CLcurrent=[interp1(CLcurrent(:,1),-stretchSize+1:100+stretchSize,'*PCHIP','extrap')',...
%                 interp1(CLcurrent(:,2),-stretchSize+1:100+stretchSize,'*PCHIP','extrap')'];
%                   CLcurrent=[smooth(CLcurrent(:,1),5), smooth(CLcurrent(:,2),5)];
%                         CLdistance=[0;cumsum(sqrt(sum(diff(CLcurrent).^2,2)))];
%           %  CLdistance=1+CLdistance/CLdistance(end)*99;
%             CLcurrent=[interp1(CLdistance,CLcurrent(:,1),1:max(CLdistance),'*PCHIP','extrap')',...
%                 interp1(CLdistance,CLcurrent(:,2),1:max(CLdistance),'*PCHIP','extrap')'];
%       
            %%
        for iSlice=1:length(imageIdx)
            %  progressbar(iStack/max(stackIdx),iSlice/length(imageIdx))
            iFrame=imageIdx(iSlice);
            iTime=hiResData.frameTime(iFrame);
            %interpolate using time to get low res idx
            hiResIdx=(iFrame);
            
            bfIdx=round(bfIdxLookup(hiResIdx));
            fluorIdx=round(fluorIdxLookup(hiResIdx));
         
            status=fseek(Fid,2*(hiResIdx+z2ImageIdxOffset)*nPix,-1);
            
            pixelValues=fread(Fid,nPix,'uint16',0,'l');
            
            hiResImage=(reshape(pixelValues,row,col));
            hiResImage=hiResImage-backgroundImage;
            hiResImage(hiResImage<0)=0;
            activityChannel=hiResImage((rect2(2)+1):rect2(4),(1+rect2(1)):rect2(3));
            segmentChannel=hiResImage((rect1(2)+1):rect1(4),(1+rect1(1)):rect1(3));
            activityChannel=imwarp(activityChannel,S2AHiRes.t_concord,'OutputView',S2AHiRes.Rsegment);
            activityChannel=pedistalSubtract(activityChannel,5);
            %
            %  hiResImage2=imwarp(hiResImage,Hi2LowRes.t_concord,...
            %     'OutputView',Hi2LowRes.Rsegment);
            
            fluorFrame=read(fluorVidObj,round(fluorIdx));
         %   bfFrame = read(behaviorVidObj,round(bfIdx));
            fluorFrame=fluorFrame(:,:,1);
          %  bfFrame=bfFrame(:,:,1);
            fluorFrame2=imwarp(fluorFrame,Hi2LowResF.t_concord,...
                'OutputView',Hi2LowResF.Rsegment);
            fluorFrame2=fluorFrame2((rect1(2)+1):rect1(4),(1+rect1(1)):rect1(3));
            lowResFluorStack(:,:,iSlice)=fluorFrame2;

            
                        activityStack(:,:,iSlice)=activityChannel;
                        segmentStack(:,:,iSlice)=segmentChannel;
        end

        fclose(Fid);
        
      activityStack=pedistalSubtract(activityStack,8);
      segmentStack=pedistalSubtract(segmentStack,8);
 %       smoothedSegmentStack=smooth3(highResInterpStack,'gaussian',[101,101,11],50);
        %%
        stackSize=size(segmentStack,3);
        
        %find middle, ie where the ventral nerve cord is, its in the lower half of
        %the worm and is a peak in the I(z) plot, but not too close to top and
        %bottom
        

        %%
        
        tempMid=lowResFluorStack(:,:,20);
        im=[]; Bx=[]; By=[]; Fx=[]; Fy=[];segmentStack3=[];activtyStack3=[];
 Rsegment = imref2d(size(tempMid));
[fluorIdxStackUnique,ib,ia]=unique(round(fluorIdxStack));
        for iSlice=1:length(ib);
            
%         contourMoving=Cout{iSlice};
%        subSamp=randsample(length(contourMoving),60);
       tempFirst=lowResFluorStack(:,:,ib(iSlice));
      [~,Bx(:,:,iSlice),By(:,:,iSlice),Fx(:,:,iSlice),Fy(:,:,iSlice)] = register_images(tempFirst,tempMid,Options);
        end
  %      [Xgrid,Ygrid,Zgrid]=ndgird(1:size(Fx,1),1:size(Fx,2),fluorIdxStackUnique);
 
  %%
        currentFiducials=fiducialPoints{iStack};

        fiducialIdx=find(cell2mat((cellfun(@(x) ~isempty(x),currentFiducials(:,1),'uniformoutput',0))));
        [fiducialIdx,~,ib]=intersect(fiducialIdx,masterFiducialIdx);
                 fiducialZ=round(interp1(z2ImageIdxOffset+imageIdx+(1:length(imageIdx))'*.0001,1:length(imageIdx),cell2mat(currentFiducials(fiducialIdx,4))));

        currentFiducials=[cell2mat(currentFiducials(fiducialIdx,1:2)) fiducialZ];        

        %% transform all stacks and fiducials
        
   segmentStack2=[];   activityStack2=[];  lowResFluorStack2=[];
   newFiducials=currentFiducials;
  for iSlice=1:stackSize
segmentStack2(:,:,iSlice)=movepixels(segmentStack(:,:,iSlice),Bx(:,:,ia(iSlice)),By(:,:,ia(iSlice)));
activityStack2(:,:,iSlice)=movepixels(activityStack(:,:,iSlice),Bx(:,:,ia(iSlice)),By(:,:,ia(iSlice)));
lowResFluorStack2(:,:,iSlice)=movepixels(lowResFluorStack(:,:,iSlice),Bx(:,:,ia(iSlice)),By(:,:,ia(iSlice)));
inSliceFiducials=currentFiducials(currentFiducials(:,3)==iSlice,1:2);
newFiducials(currentFiducials(:,3)==iSlice,1:2)=...
    movecoordinates(inSliceFiducials,Fy(:,:,ia(iSlice)),Fx(:,:,ia(iSlice)));
        
  end
  
  
  
        
  
  %% straighten via centerline, move control points
%       [X,Y,stackGrid]=meshgrid(1:size(newYHiFout,2),1:size(newYHiFout,1),1:stackSize);
%        segmentStack3=interp3(segmentStack2,newYHiFout,newXHiFout,stackGrid,'*linear',0);
%         activityStack3=interp3(activityStack2,newYHiFout,newXHiFout,stackGrid,'*linear',0);
%         segmentStack3(isnan(segmentStack3))=0;
%         activityStack3(isnan(activityStack3))=0;
%         
%         newFiducials=currentFiducials;
%         for iFiducials=1:size(currentFiducials,1);
%             zSlice=currentFiducials(iFiducials,3);
%             subX=newXHiFout(:,:,zSlice);
%             subY=newYHiFout(:,:,zSlice);
%             k=dsearchn([subX(:) subY(:)],currentFiducials(iFiducials,[2,1]));
%             [newXpt, newYpt]=ind2sub(size(subX),k);
%             newFiducials(iFiducials,1:2)=[newXpt newYpt];
%         end
segmentStack3=segmentStack2;
activityStack3=activityStack2;
currentFiducials=newFiducials;
        segmentStack3(isnan(segmentStack3))=0;
         activityStack3(isnan(activityStack3))=0;
        
  %% move contol points
        
%%
     if iStack~=masterFIdx

        
        %% fiducial alignment
  
        %affine transformation
  %      tform = makeAffine3d(currentFiducials(:,[2 1 3]), masterFiducials(fiducialIdx,[2 1 ,3]));
        tform = makeAffine3d(currentFiducials, masterFiducials(ib,:));

  Rsegment2 = imref3d(size(segmentStack3));
        segmentStack4=imwarp(segmentStack3,tform,'OutputView',Rsegment2);
         activityStack4=imwarp(activityStack3,tform,'OutputView',Rsegment2);
affineFiducials=[];
           [affineFiducials(:,1),affineFiducials(:,2),affineFiducials(:,3)]...
               =transformPointsForward(tform,currentFiducials(:,1),...
               currentFiducials(:,2),currentFiducials(:,3));   
           
           
%[segmentStack5,xlookup,ylookup,zlookup]= tpswarp3(segmentStack4, size(refstack), masterFiducials(fiducialIdx,[1 2 3]),affineFiducials(:,[1 2 3]));  
[segmentStack5,xlookup,ylookup,zlookup]= tpswarp3(segmentStack4, size(refstack), masterFiducials(ib,[2 1 3]),affineFiducials(:,[2 1 3]));  

activityStack5=interp3(activityStack4,ylookup,xlookup,zlookup,'*linear');
segmentStack5(isnan(segmentStack5))=0;
activityStack5(isnan(activityStack5))=0;
           % followed by bspline Transformation
%         [O_trans,Spacing,Xreg]=point_registration(size(refstack),affineFiducials,masterFiducials(fiducialIdx,:),Options2);       
%  [segmentStack5,T]=bspline_transform(O_trans,segmentStack4,Spacing,3);
%          %activityStack4=activtyStack3;

            
        else
       segmentStack5=segmentStack3;
       activityStack5=activtyStack3;
        end
        
        

        %%
        
        %    title(num2str(bfIdx));
        metaData(i).metaData.time=time;
        metaData(i).metaData.zVoltage=zPos;
        metaData(i).metaData.iFrame=imageIdx;
        metaData(i).metaData.midPlane=20;
        metaData(i).imageIdx=imageIdx+z2ImageIdxOffset;
        metaData(i).fluorIdx=round(fluorIdxLookup(imageIdx));
        metaData(i).bfIdx=round(bfIdxLookup(imageIdx));
        fileName=['image' num2str(iStack,'%3.5d') '.tif'];
        if saveFlag
            
            tiffwrite([hiResActivityFolder filesep fileName],single(activityStack5),'tif',0);
            tiffwrite([hiResSegmentFolder filesep fileName],single(segmentStack5),'tif',0);
            tiffwrite([hiResSegmentFolderRaw filesep fileName],single(segmentStack),'tif',0);
            tiffwrite([hiResActivityFolderRaw filesep fileName],single(activityStack),'tif',0);
%     
%            
%             if lookupSave
%                 
%                 
%                 [Ireg,Bx,By,Fx,Fy] = register_images(tempAlign,maxRef,Options);
% 
%                 tiffwrite([lookupFolderX filesep fileName],single(Fx),'tif',0);
%                 tiffwrite([lookupFolderY filesep fileName],single(Fy),'tif',0);
%                 
%             end
            
        end
        display(['Finished frame: ' num2str(iStack) ' in ' num2str(toc) 's']);
    catch me
        display(['Error frame: ' num2str(iStack)]);
    end
    
end

for i=1:length(metaData);
        iStack=hasPoints(group(i));

    matName=['image' num2str((iStack),'%3.5d')];
    parsave([metaFolder filesep matName],metaData(i),'metaData');
    display(['Saving ' matName]);

end

end
