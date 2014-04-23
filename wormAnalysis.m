

%load folder and extract and align timing data.
imFolder=uigetdir;
[initialIm,stackInfo]=timeTraceAnalysis(imFolder);

%% better initial Im by averaging multiple stacks and doing a max projection
%!!! may be better to just take images from BEFORE the flash,
%photobleaching appears to make these images better than my averaging. 
clear worm
wormAll=zeros(size(initialIm,1),size(initialIm,2),length(stackInfo(1).z));
for i=1:2:31
stackSize=length(stackInfo(i).fileNames);

    for slice=1:min(length(stackInfo(1).z),stackSize)
        
        temp=double(imread([imFolder filesep stackInfo(i).fileNames(slice).name],'tif'));
                temp=pixelIntensityCorrection(temp);
        %worm(:,:,slice)=temp;
        wormAll(:,:,slice)=wormAll(:,:,slice)+double(temp);
    end
end
initialIm=max(wormAll,[],3);
save([imFolder filesep 'stackInfo'],'stackInfo','initialIm');





%% Draw 2 rectangles for the shape and activity channels
fig=imagesc(initialIm);
display('Get segmenting ROI')
rect1=getrect(gcf);
rect1=round(rect1);
rectSize1=rect1(3:4);
rect1=round(rect1 +[0,0 rect1(1:2)]);
channelSegment=initialIm((rect1(2)+1):rect1(4),(1+rect1(1)):rect1(3));
display('Get Activity ROI');
rect2=getrect(gcf);
rect2=round(rect2);
rectSize2=rect2(3:4);
rect2=round(rect2 +[0,0 rect2(1:2)]);
channelActivity=initialIm((rect2(2)+1):rect2(4),(1+rect2(1)):rect2(3));


channelSegment=normalizeRange(double(channelSegment));
channelActivity=normalizeRange(double(channelActivity));
close all
%% Select control points and create transform
[activityPts,segmentPts]=cpselect(wiener2(channelActivity,[3,3],1),channelSegment,...
                'Wait',true);
t_concord = fitgeotrans(activityPts,segmentPts,'projective');
Rsegment = imref2d(size(channelSegment));
activityRegistered = imwarp(channelActivity,t_concord,'OutputView',Rsegment);
padRegion=activityRegistered==0;
padRegion=imdilate(padRegion,true(3));

save([imFolder filesep 'stackInfo'],'rect1','rect2','t_concord'...
    ,'Rsegment','rectSize1','rectSize2','padRegion','imFolder','-append');

%% segment subimages and create masks

mkdir([imFolder filesep 'stackData']);


for iStack=504:length(stackInfo);
    tic
stackSize=length(stackInfo(iStack).fileNames);
    worm=zeros(rectSize1(2),rectSize1(1),stackSize);
    activity=worm;
    % load stacks
    for slice=1:stackSize
        
        temp=double(imread([imFolder filesep stackInfo(iStack).fileNames(slice).name],'tif'));
        temp=pixelIntensityCorrection(temp);
        temp_activity=temp((rect2(2)+1):rect2(4),(1+rect2(1)):rect2(3));
        worm(:,:,slice)=temp((rect1(2)+1):rect1(4),(1+rect1(1)):rect1(3));
        temp_activity=imwarp(temp_activity,t_concord,'OutputView',Rsegment);
        temp_activity(padRegion)=median(temp_activity(~padRegion));
        activity(:,:,slice)=temp_activity;
    end
    imsize=size(worm);  
    %resize image, arbitrary for now
   worm=image_resize(worm,imsize(1),imsize(2),2*imsize(3));
      activity=image_resize(activity,imsize(1),imsize(2),2*imsize(3));
%do segmentation
    wormMask=WormSegmentHessian(worm);
    
    %look up intensities on both channels
    wormLabelMask=bwlabeln(wormMask);
wormcc=bwconncomp(wormMask);
stats=regionprops(wormcc,'Centroid','Area');
centroids=reshape([stats.Centroid],3,[])';
Rintensities=cellfun(@(x) mean(worm(x)),[wormcc.PixelIdxList])';
Gintensities=cellfun(@(x) mean(activity(x)),[wormcc.PixelIdxList])';

    %interpolate Z properly and scale
centroids(:,3)=interp1(stackInfo(iStack).z,centroids(:,3)/2)*100; %arb scaling for now
Volume=[stats.Area]';
realTime=interp1(stackInfo(iStack).time,centroids(:,3)/2); %arb scaling for now

%save outputs in unique file
outputFile=[imFolder filesep 'stackData' filesep 'stack' num2str(iStack,'%04d') 'data'];

save(outputFile,'centroids','Rintensities','Gintensities','Volume','realTime',...
    'wormMask');
display(['Completed stack' num2str(iStack,'%04d') ' in ' num2str(toc) ' seconds']);
end
