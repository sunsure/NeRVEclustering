function pointStats=combinePointStatsFiles(psFolder,psLength)
% creates a complete pointStats variable from an analysis folder which is
% created by the WormStraightening programs. Adjusted to work on the
% cluster, DOES NOT OVERWRITE EXISTING POINTSTATS FILES
if nargin==0
    dataFolder=uipickfiles;
    dataFolder=dataFolder{1};
end
if nargin==1
    dataFolder=psFolder;
end

    psFolder=dir([dataFolder filesep 'CLstraight*']);
    psFolder=[dataFolder filesep psFolder(end).name];
    pList=dir([psFolder filesep 'pointStats*']);

pointStats=repmat(struct(),1,psLength);

%progressbar(0);
for iFile=1:length(pList);
 %   progressbar(iFile/length(pList));
 if ~mod(iFile,10)
     display([ 'Completed frame ' num2str(iFile) ' of ' num2str(psLength)])
 end
 
    idx=str2double(pList(iFile).name(11:15));
    input=load([psFolder filesep pList(iFile).name]);
    input=input.pointStats;
    pointStats(idx).straightPoints=input.straightPoints;
    pointStats(idx).rawPoints=input.rawPoints;
    pointStats(idx).stackIdx=input.stackIdx;
    pointStats(idx).pointIdx=input.pointIdx;
    pointStats(idx).Rintensities=input.Rintensities;
    pointStats(idx).Volume=input.Volume;
end
save([dataFolder filesep 'PointsStats'],'pointStats');