function clusterWormCenterline(dataFolder,iCell,show2)
%clusterworm tracker fits centerlines to behavior videos from our whole
%brain imaging setup. a CL workspace must be loaded with initial parameters
%and paths in order to run this code, and the activeContourFit program
%requires the eigenworms to be loaded as "eigbasis" on to the main window. 

d= dir([dataFolder filesep 'LowMagBrain*']);
aviFolder=[dataFolder filesep d(1).name];
display(aviFolder)
gaussFilter=fspecial('gaussian',30,5);%fspecial('gaussian',10,75);
gaussFilter2=fspecial('gaussian',50,15);%fspecial('gaussian',10,75);
temp=load('eigenWorms_full.mat');
eigbasis=temp.eigvecs;
setappdata(0,'eigbasis',eigbasis);
workSpaceFile=[aviFolder filesep 'CLworkspace.mat'];
CLworkspace=load(workSpaceFile);
bfCell=CLworkspace.bfCell;
meanBfAll2=CLworkspace.meanBfAll2;
fluorBackground=CLworkspace.fluorBackground;
clStart=CLworkspace.clStart;
flashLoc=CLworkspace.flashLoc;
newZ2=CLworkspace.newZ2;
cline_para=CLworkspace.cline_para;
refIdx=cline_para.refIdx;
cline_para.showFlag=00;

if nargin==2
    show2=0;
end

startFlag=1;
cellList=bfCell{iCell};
CLall=zeros(100,2,length(cellList));
IsAll=zeros(100,length(cellList));
cm_fluor=[26 26];
sdev_nhood=getnhood(strel('disk',5));

%%
outputFolder=[aviFolder filesep 'CL_files'];
if ~exist(outputFolder,'dir')
    mkdir(outputFolder)
end

%% load avi data
camData=importdata([ aviFolder  filesep 'CamData.txt']);
time=camData.data(:,2);
fluorMovie=[aviFolder filesep 'cam0.avi'];
behaviorMovie=[aviFolder filesep 'cam1.avi'];
NFrames=length(camData.data);

behaviorVidObj = VideoReader(behaviorMovie);
fluorVidObj= VideoReader(fluorMovie);


%% load alignments
alignments=load([dataFolder filesep 'alignments']);
alignments=alignments.alignments;
lowResFluor2BF=alignments.lowResFluor2BF;

%%
for iFrame=1:length(cellList);
    %%
    iTime=cellList(iFrame);
    tic
    
    try
        if ~isnan(newZ2(iTime)) && ~any(flashLoc==iTime) && iTime>=1
            %%
            
            bfFrameRaw = read(behaviorVidObj,iTime,'native');
            bfFrameRaw=double(bfFrameRaw.cdata);
            backGroundRaw=meanBfAll2(:,:,newZ2(iTime));
            c=sum(sum(bfFrameRaw.*backGroundRaw))/sum(sum(backGroundRaw.^2));
            bfFrameRaw2=bfFrameRaw-backGroundRaw*c;
            %bfFrameRaw2=abs(bfFrameRaw2);;
            bfFrame=imtophat(bfFrameRaw2,strel('disk',50));
            bfFramestd=stdfilt(bfFrameRaw2,sdev_nhood);
            bfFramestd=normalizeRange(bfFramestd);
            bfstdthresh=(bfFramestd>graythresh(bfFramestd));
           bfFrame(bfstdthresh)=abs(bfFrame(bfstdthresh));
            bfFramestd=bpass((bfFramestd),1,80);
            bfFrame=normalizeRange(bpass(bfFrame,4,80));

            fluorFrameRaw=read(fluorVidObj,iTime,'native');
            fluorFrameRaw=double(fluorFrameRaw.cdata)-fluorBackground;
            fluorFrameRaw(fluorFrameRaw<0)=0;
            fluorFrame2=fluorFrameRaw;
            fluorFrame2=bpass(fluorFrame2,1,40);
            
            %calculate centroid of fluor image
            fluorMask=false(size(fluorFrame2));
            fluorMask(round(cm_fluor(2))+(-25:25),...
                round(cm_fluor(1))+(-25:25))=true;
            fluorBW=(fluorFrame2>(max(fluorFrame2(:))/5));
            fluorFrameMask=fluorBW.*fluorMask;
            if (any(fluorFrameMask(:))) && ~startFlag
                fluorBW=fluorFrameMask;
            end
            
            fluorBW=AreaFilter(fluorBW); %select only largest obj
            
            [cmy,cmx]=find(fluorBW);
            cm_fluor=mean([cmx cmy]);
            cm=transformPointsForward(lowResFluor2BF.t_concord,cm_fluor);
            inputImage=2*bfFrame/max(bfFrame(:))+normalizeRange(bfFramestd);
            inputImage(inputImage<0)=0;
            %       inputImage=sqrt(inputImage);
            inputImage=filter2(gaussFilter,inputImage,'same');
            inputImage=inputImage-min(inputImage(:));
            inputImage=normalizeRange(inputImage);
           % maxThresh=quantile(inputImage(inputImage>.2),.90);
          %  inputImage=inputImage/maxThresh;
            bfFramestd=normalizeRange(imfilter(bfFramestd,gaussFilter2));
            bfFrameMask=(bfFramestd>min(graythresh(bfFramestd),.7));
            tipImage=bfFrameMask.*inputImage;
            bfFrameLTmask=bfFrameMask & tipImage<bfFramestd;
            tipImage(bfFrameLTmask)=bfFramestd(bfFrameLTmask);
            %%
            if startFlag
                
                CLold=clStart{iCell};
                CLold=distanceInterp(CLold,100);
                
                
                [CLOut,Is]=ActiveContourFit_wormRef4(...
                    inputImage,tipImage, cline_para, CLold,refIdx,cm);
                startFlag=0;
            else
                
                oldTime=iFrame-1;
                while isnan(newZ2(cellList(oldTime)));
                    oldTime=oldTime-1;
                end
                
                CLold=CLall(:,:,oldTime);
                [CLOut,Is,Eout]=ActiveContourFit_wormRef4(...
                    inputImage,tipImage, cline_para, CLold,refIdx,cm);
                
            end
            
            if ~mod(iTime,show2)
                subplot(1,2,1)
                imagesc(bfFrameRaw2);
                % colormap gray
                hold on
                plot(CLOut(:,1),CLOut(:,2),'r');
                plot(CLOut([1 end],1),CLOut([1 end],2),'og');
                scatter(cm(1),cm(2),'gx');
                plot([CLOut(refIdx,1) cm(1)],[CLOut(refIdx,2) cm(2)],'g');
                %quiver(xyzs(:,1),xyzs(:,2),fs(:,1),fs(:,2),'black');
                hold off
                subplot(1,2,2);
                imagesc(tipImage);
                % colormap gray
                hold on
                plot(CLOut(:,1),CLOut(:,2),'r');
                plot(CLOut([1 end],1),CLOut([1 end],2),'og');
                scatter(cm(1),cm(2),'gx');
                plot([CLOut(refIdx,1) cm(1)],[CLOut(refIdx,2) cm(2)],'g');
                %quiver(xyzs(:,1),xyzs(:,2),fs(:,1),fs(:,2),'black');
                hold off
                drawnow
            end
            CLOut=distanceInterp(CLOut,100);
            
            CLall(:,:,iFrame)=CLOut;
            IsAll(:,iFrame)=Is;
        else
            CLall(:,:,iFrame)=CLall(:,:,iFrame-1);
            IsAll(:,iFrame)=IsAll(:,iFrame-1);
        end
        display(['Completed frame '  num2str(iTime) ', cell '...
            num2str(iCell) ' in ' num2str(toc) ' s'])
    catch me
        display(['error frame ' num2str(iTime) ', cell ' num2str(iCell)])
        if cline_para.showFlag==0 && show2==0
        me
        end
        if iFrame>1
           CLall(:,:,iFrame)=CLall(:,:,iFrame-1);
           IsAll(:,iFrame)=IsAll(:,iFrame-1);
        else
            CLold=clStart{iCell};
            CLold=distanceInterp(CLold,100);
            CLall(:,:,iFrame)=CLold;
            IsAll(:,iFrame)=0;
        end
        
            
      
    end
end

outputFilename=[outputFolder filesep 'CL_' num2str(iCell,'%3.2d')];
save(outputFilename,'CLall','IsAll','cellList');
