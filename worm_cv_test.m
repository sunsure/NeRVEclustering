%select file name

movieFile=uipickfiles('FilterSpec','Y:\PanNeuronal\20140819');

%% load vidObj using VideoReader
vidObj = VideoReader(movieFile{1});
lastFrame = read(vidObj, inf);
 numFrames= vidObj.NumberOfFrames;

%% load some number of stacks
clear imStack
clear unFilteredStack
stackCounter=1;
for iFrame=1:1:min(40,numFrames)
    
lastFrame = read(vidObj, iFrame);


lastFrame=normalizeRange(sum(double(lastFrame),3));
lastFramebp=bpass(lastFrame,.5,[10,10]);

imStack(:,:,stackCounter)=lastFramebp;
unFilteredStack(:,:,stackCounter)=lastFrame;
stackCounter=stackCounter+1;
end
%%
imagesc(max(imStack,[],3));
rect=round(getrect);
imStackCrop=imStack(rect(1):rect(1)+rect(3),rect(2):rect(2)+rect(4),:);

imStackSmooth=smooth3(imStackCrop,'box',[3,3,5]);

%%
smooth_weight = .001; 
image_weight = 100; 
delta_t = 4; 

%%
V=imStackSmooth;

margin = 10; 
phi = zeros(size(V)); 
phi(margin:end-margin, margin:end-margin, margin:end-margin) = 1; 
phi = ac_reinit(phi-.5); 


%%
phi2=repmat(phi(:,:,20),[1,1,1])-20;

%%
imshow(V(:,:,1));
hold on
for i = 1:20
    phi2 = ac_ChanVese_model(max(phi2(:))*normalizeRange(V(:,:,1)), phi2, smooth_weight, image_weight, delta_t, 1); 
    
    if exist('h','var') && all(ishandle(h)),delete(h); end
 %  h = patch(iso,'facecolor','w');  axis equal;  view(3); 
  [C,h]=contour(phi2,[0,0],'w');axis equal;
  
    set(gcf,'name', sprintf('#iters = %d',i));
    drawnow; 
end
contours(1).C=C;
hold off
%%

for iFrame = 2:numFrames
    lastFrame = read(vidObj, iFrame);
    lastFrame=lastFrame(rect(1):rect(1)+rect(3),rect(2):rect(2)+rect(4));

    lastFrame=normalizeRange(sum(double(lastFrame),3));

lastFrame=bpass(lastFrame,.5,[30,30]);

    
    imshow(lastFrame);
    hold on
    for iIterations=1:10
    phi2 = ac_ChanVese_model(max(phi2(:))*lastFrame, phi2, smooth_weight, image_weight, delta_t, 1); 
    
    if exist('h','var') && all(ishandle(h)),delete(h); end
 %  h = patch(iso,'facecolor','w');  axis equal;  view(3); 
  [C,h]=contour(phi2,[0,0],'w');axis equal;
  
    set(gcf,'name', sprintf('#iters = %d , #frame = %d',iIterations,iFrame));
    drawnow; 
    end
    contours(iFrame).C=C;
    hold off
end






%%
figure;
slice = [10,15,20,25,30,35,40,45];
for i = 1:8
    subplot(2,4,i); imshow(V(:,:,slice(i)),[]); hold on; 
    c = contours(phi(:,:,slice(i)),[0,0]);
    zy_plot_contours(c,'linewidth',2);
end