function varargout = scanBinaryImageStack(varargin)
% SCANBINARYIMAGESTACK MATLAB code for scanBinaryImageStack.fig
%      SCANBINARYIMAGESTACK, by itself, creates a new SCANBINARYIMAGESTACK or raises the existing
%      singleton*.
%
%      H = SCANBINARYIMAGESTACK returns the handle to a new SCANBINARYIMAGESTACK or the handle to
%      the existing singleton*.
%
%      SCANBINARYIMAGESTACK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SCANBINARYIMAGESTACK.M with the given input arguments.
%
%      SCANBINARYIMAGESTACK('Property','Value',...) creates a new SCANBINARYIMAGESTACK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before scanBinaryImageStack_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to scanBinaryImageStack_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help scanBinaryImageStack

% Last Modified by GUIDE v2.5 12-Sep-2014 15:39:00

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @scanBinaryImageStack_OpeningFcn, ...
                   'gui_OutputFcn',  @scanBinaryImageStack_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before scanBinaryImageStack is made visible.
function scanBinaryImageStack_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to scanBinaryImageStack (see VARARGIN)

% Choose default command line output for scanBinaryImageStack
handles.output = hObject;
hlistener=addlistener(handles.slider1,'ContinuousValueChange',...
    @showImage);


setappdata(handles.figure1,'holdaxes',false);
setappdata(handles.slider1,'hlistener',hlistener);
set(handles.slider1,'Max',2000);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes scanBinaryImageStack wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = scanBinaryImageStack_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in selectFolder.
function selectFolder_Callback(hObject, eventdata, handles)
% hObject    handle to selectFolder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
mostRecent=getappdata(0,'mostRecent');

try
currentData=uipickfiles('FilterSpec',mostRecent);
catch
    currentData=uipickfiles();
end
currentData=currentData{1};

setappdata(0,'mostRecent',fileparts(currentData));
set(handles.currentFolder,'String',currentData);
Fid=fopen(currentData);
status=fseek(Fid,0,1);
nFrames=ftell(Fid)/(2*1024^2)-1;
setappdata(handles.figure1,'nFrames',nFrames);
set(handles.slider1,'Value',1);
set(handles.slider1,'Max',nFrames);
setappdata(0,'Fid',Fid);


function showImage(hObject,eventdata)

handles=guidata(get(hObject,'Parent'));
Fid=getappdata(0,'Fid');

frameNumber=get(handles.slider1,'Value');
frameNumber=round(frameNumber);
status=fseek(Fid,2*frameNumber*1024^2,-1);
if ~status
  frewind(Fid) 
  status=fseek(Fid,2*frameNumber*1024^2,-1);

end
pixelValues=fread(Fid,1024^2,'uint16',0,'l');
C=reshape(pixelValues,1024,1024);
h=imagesc(C,'Parent',handles.axes1);
set(handles.currentFrame,'String',num2str(frameNumber));
