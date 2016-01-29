unit ExtUnit;

interface
uses System.IniFiles, System.SyncObjs, System.SysUtils, System.IOUtils, System.Classes,IdCustomTCPServer, IdTCPServer, IdContext, Windows;

type
TLanDataPackage = Record
  CommandStr : string;
  CommandStrLen:integer;
  CommandParameters : string;
  CommandParametersLen:integer;
  CommandData : widestring;
  CommandDataLen:integer;
  DataFileName:String;
  DataFileNameLen:integer;
  DataFileNameList:string;
  DataFileNameListLen:integer;
end;

TLanServer = class (TIdTCPServer)
//private
//  wHosts:string;
end;

TLanServerEvent = class
  procedure LanServerConnected(AContext: TIdContext);
  procedure LanServerDisconnected(AContext: TIdContext);
  procedure LanServerExecute(AContext: TIdContext);
end;

  function IniFileRead(DParam:string):String;
  function IniFileWrite(DParam,DValue:string):String;
  function GetResponseData(InData:TLanDataPackage):TLanDataPackage;
  function GetParseStringParams(SourceString: string; NumberParameter:integer):String;
  function GetParseStringCount(SourceString: string):Integer;
  function GetParseParameter(SourceString: string; ReturnValue:integer):String;
  function GetFindStringParams(SourceString: string; ParamsName:string):String;
  procedure SetLog(TextLog:string);
  procedure SaveDataToStream(DataIn:TLanDataPackage; var StreamOut: TMemoryStream);
  procedure LoadDataFromStream(StreamIn: TMemoryStream; var DataOut:TLanDataPackage );


var
  CS_SetLog: TCriticalSection;
  LanServer:TLanServer;
  LanServerEvent:TLanServerEvent;

implementation
uses Main;



procedure SaveDataToStream(DataIn:TLanDataPackage; var StreamOut: TMemoryStream);
var
  StreanFileTemp : TMemoryStream;
  CountFiles,i:integer;
  FileNameTmp:string;
begin
  DataIn.CommandStrLen:=Length(DataIn.CommandStr);
  DataIn.CommandParametersLen:=Length(DataIn.CommandParameters);
  DataIn.CommandDataLen:=Length(DataIn.CommandData);
  DataIn.DataFileNameLen:=Length(DataIn.DataFileName);
  DataIn.DataFileNameList:=''; // DataIn.DataFileName Должен быть в формате Файл01;файл02;
  CountFiles:=GetParseStringCount(DataIn.DataFileName);
  if CountFiles > 0 then
  begin
    SetLog('CountFiles '+IntToStr(CountFiles)) ;
    for I := 0 to CountFiles-1 do
    begin
      FileNameTmp:= GetParseStringParams(DataIn.DataFileName, i);
      if FileExists(PathHomeProgramm+PathExchangeFolder+FileNameTmp)=True then
      begin
        SetLog('Предварительный поиск: Файл '+FileNameTmp+' найден');
        try
          try
            StreanFileTemp:=TMemoryStream.Create;
            StreanFileTemp.LoadFromFile(PathHomeProgramm+PathExchangeFolder+FileNameTmp);
            DataIn.DataFileNameList:=DataIn.DataFileNameList+FileNameTmp+':'+IntToStr(StreanFileTemp.Size)+';';
          finally
            FreeAndNil(StreanFileTemp);
          end;
        except
        on E: Exception do SetLog('Ошибка отправки файла данных '+E.ClassName + ': ' + E.Message);
        end;
      end
      else
        SetLog('Предварительный поиск:  Файл '+FileNameTmp+' НЕ найден') ;
    end;
  end;
  SetLog('DataIn.DataFileNameList '+DataIn.DataFileNameList) ;
  DataIn.DataFileNameListLen:=Length(DataIn.DataFileNameList);
  SetLog('Данные SaveDataToStream CommandStr '+DataIn.CommandStr+' CommandParameters '+DataIn.CommandParameters+' CommandData '+DataIn.CommandData+' DataFileName '+DataIn.DataFileName+' DataFileNameList '+DataIn.DataFileNameList);
  SetLog('Данные SaveDataToStream CommandStrLen '+IntToStr(DataIn.CommandStrLen)+' CommandParametersLen '+IntToStr(DataIn.CommandParametersLen)+' CommandDataLen '+IntToStr(DataIn.CommandDataLen)+' DataFileNameLen '+IntToStr(DataIn.DataFileNameLen)+' DataFileNameListLen '+IntToStr(DataIn.DataFileNameListLen));
  StreamOut.Write(DataIn.CommandStrLen, SizeOf(DataIn.CommandStrLen));
  if(SizeOf(DataIn.CommandStrLen) > 0)then StreamOut.Write(DataIn.CommandStr[1], DataIn.CommandStrLen * SizeOf(DataIn.CommandStr[1]));
  StreamOut.Write(DataIn.CommandParametersLen, SizeOf(DataIn.CommandParametersLen));
  if(SizeOf(DataIn.CommandParametersLen) > 0)then StreamOut.Write(DataIn.CommandParameters[1], DataIn.CommandParametersLen * SizeOf(DataIn.CommandParameters[1]));
  StreamOut.Write(DataIn.CommandDataLen, SizeOf(DataIn.CommandDataLen));
  if(SizeOf(DataIn.CommandDataLen) > 0)then StreamOut.Write(DataIn.CommandData[1], DataIn.CommandDataLen * SizeOf(DataIn.CommandData[1]));
  StreamOut.Write(DataIn.DataFileNameListLen, SizeOf(DataIn.DataFileNameListLen));
  if (DataIn.DataFileNameLen > 0) and (CountFiles > 0) then
  begin
    if(SizeOf(DataIn.DataFileNameListLen) > 0)then StreamOut.Write(DataIn.DataFileNameList[1], DataIn.DataFileNameListLen * SizeOf(DataIn.DataFileNameList[1]));
    CountFiles:=GetParseStringCount(DataIn.DataFileNameList);
    if CountFiles > 0 then
    begin
      for I := 0 to CountFiles-1 do
      begin
        FileNameTmp:= GetParseParameter(GetParseStringParams(DataIn.DataFileNameList, i),0);
        if FileExists(PathHomeProgramm+PathExchangeFolder+FileNameTmp)=True then
        begin
          SetLog('Файл для отправки '+FileNameTmp+' найден');
          try
            try
              StreanFileTemp:=TMemoryStream.Create;
              StreanFileTemp.LoadFromFile(PathHomeProgramm+PathExchangeFolder+FileNameTmp);
              StreamOut.CopyFrom(StreanFileTemp,StreanFileTemp.Size);
              SetLog('StreamOut.Position '+InttOsTR(StreamOut.Position)) ;
            finally
              FreeAndNil(StreanFileTemp);
            end;
          except
          on E: Exception do SetLog('Ошибка отправки файла данных '+E.ClassName + ': ' + E.Message);
          end;
        end
        else
          SetLog('Файл для отправки '+FileNameTmp+' НЕ найден') ;
      end;
    end;
  end;
end;

procedure LoadDataFromStream(StreamIn: TMemoryStream; var DataOut:TLanDataPackage );
var
  StreanFileTemp : TMemoryStream;
  CountFiles, i, SizeFileTmp:integer;
  FileNameTmp:string;
begin
  StreamIn.Position:=0;
  StreamIn.Read(DataOut.CommandStrLen, SizeOf(DataOut.CommandStrLen));
  if(DataOut.CommandStrLen > 0)then begin
    SetLength(DataOut.CommandStr, DataOut.CommandStrLen);
    StreamIn.Read(DataOut.CommandStr[1], DataOut.CommandStrLen * SizeOf(DataOut.CommandStr[1]));
  end else DataOut.CommandStr := '';
  StreamIn.Read(DataOut.CommandParametersLen, SizeOf(DataOut.CommandParametersLen));
  if(DataOut.CommandParametersLen > 0)then begin
    SetLength(DataOut.CommandParameters, DataOut.CommandParametersLen);
    StreamIn.Read(DataOut.CommandParameters[1], DataOut.CommandParametersLen * SizeOf(DataOut.CommandParameters[1]));
  end else DataOut.CommandParameters := '';
  StreamIn.Read(DataOut.CommandDataLen, SizeOf(DataOut.CommandDataLen));
  if(DataOut.CommandStrLen > 0)then begin
    SetLength(DataOut.CommandData, DataOut.CommandDataLen);
    StreamIn.Read(DataOut.CommandData[1], DataOut.CommandDataLen * SizeOf(DataOut.CommandData[1]));
  end else DataOut.CommandData := '';
  StreamIn.Read(DataOut.DataFileNameListLen, SizeOf(DataOut.DataFileNameListLen));
  if DataOut.DataFileNameListLen > 0 then
  begin
    SetLength(DataOut.DataFileNameList, DataOut.DataFileNameListLen);
    StreamIn.Read(DataOut.DataFileNameList[1], DataOut.DataFileNameListLen * SizeOf(DataOut.DataFileNameList[1]));
    SetLog(' Получено описание '+DataOut.DataFileNameList);
    CountFiles:=GetParseStringCount(DataOut.DataFileNameList);
    if CountFiles > 0 then
    begin
      SetLog('Описано '+IntToStr(CountFiles));
      for I := 0 to CountFiles-1 do
      begin
        FileNameTmp:= GetParseParameter(GetParseStringParams(DataOut.DataFileNameList, i),0);
        SizeFileTmp:=StrToInt(GetParseParameter(GetParseStringParams(DataOut.DataFileNameList, i),1));
        SetLog('Файл описан '+FileNameTmp + ' размер ' + IntToStr(SizeFileTmp));
        try
          try
            StreanFileTemp:=TMemoryStream.Create;
            StreanFileTemp.CopyFrom(StreamIn,SizeFileTmp);
            StreanFileTemp.SaveToFile(PathHomeProgramm+PathExchangeFolder+FileNameTmp);
            if FileExists(PathHomeProgramm+PathExchangeFolder+FileNameTmp)=True then SetLog('Файл '+PathHomeProgramm+PathExchangeFolder+FileNameTmp+' найден') else SetLog('Файл '+PathHomeProgramm+PathExchangeFolder+FileNameTmp+' НЕ найден') ;
            DataOut.DataFileName:=DataOut.DataFileName+FileNameTmp+';';
          finally
            FreeAndNil(StreanFileTemp);
          end;
        except
          on E: Exception do SetLog('Ошибка получения файла данных '+E.ClassName + ': ' + E.Message);
        end;
      end;
    end;
  end
  else
  begin
    DataOut.DataFileNameList := '';
    DataOut.DataFileNameListLen:=0;
  end;
  SetLog('Данные LoadFromStream CommandStr '+DataOut.CommandStr+' CommandParameters '+DataOut.CommandParameters+' CommandData '+DataOut.CommandData+' DataFileName '+DataOut.DataFileName+' DataFileNameList '+DataOut.DataFileNameList);
  SetLog('Данные LoadFromStream CommandStrLen '+IntToStr(DataOut.CommandStrLen)+' CommandParametersLen '+IntToStr(DataOut.CommandParametersLen)+' CommandDataLen '+IntToStr(DataOut.CommandDataLen)+' DataFileNameLen '+IntToStr(DataOut.DataFileNameLen)+' DataFileNameListLen '+IntToStr(DataOut.DataFileNameListLen));
end;

function IniFileRead(DParam:string):String;
var
  RFileIni: TIniFile;
begin
  Result:='';
  if FileExists(PathHomeProgramm + 'ConfigFile.ini') then
  begin
    RFileIni:= TIniFile.Create(PathHomeProgramm + 'ConfigFile.ini');
    try
      Result:=Trim(RFileIni.ReadString('Main',DParam,''));
    finally
      RFileIni.Free;
    end;
  end;
end;

function IniFileWrite(DParam,DValue:string):String;
var
  WFileIni: TIniFile;
begin
  Result:='';
  WFileIni:= TIniFile.Create(Trim(PathHomeProgramm) + 'ConfigFile.ini');
  try
    WFileIni.WriteString('Main',DParam,DValue);
    Result:='Данные записаны';
  finally
    WFileIni.Free;
  end;
end;

function GetResponseData(InData:TLanDataPackage):TLanDataPackage;
var
  OutData:TLanDataPackage;
  StringParametersTmp,StringDataTmp:String;
begin
  StringParametersTmp:='';
  StringDataTmp:='';
  OutData.CommandStr:='';
  OutData.CommandParameters:='';
  OutData.CommandData:='';
  OutData.DataFileName:='';
  OutData.DataFileNameList:='';

  if Trim(InData.CommandStr)='TSCALoader:CheckUpdate;' then
  begin
    if Trim(IniFileRead('ClientVersion')) <> Trim(GetParseStringParams(GetParseParameter(InData.CommandData, 1),0)) then
    begin
      SetLog('If '+Trim(IniFileRead('ClientVersion'))+' - '+Trim(GetParseParameter(InData.CommandData, 1)));
      OutData.CommandStr:='TSCALoader:UpdateChecked';
      OutData.CommandParameters:='SendingUpdates';
      OutData.CommandData:='TSCALoaderClientVersion:UpdatedToVersion '+Trim(IniFileRead('ClientVersion'));
      OutData.DataFileName:=Trim('TSCA_Client.exe;');
    end
    else
    begin
      OutData.CommandStr:='TSCALoader:UpdateChecked';
      OutData.CommandParameters:='No Update';
      OutData.CommandData:='TSCALoaderClientVersion:No Update';
      OutData.DataFileName:='';
    end;
  end;




  if Trim(InData.CommandStr)='TSCAClient:CheckClientData;' then
  begin
    SetLog('Формирование запроса для TSCAClient:CheckClientData');
    // CommandParameters CInfoPCNames:PC-900000002;CInfoUserName:Chubukin_DV;CInfoClientName:sf;CInfoOSMajor:6;CInfoOSMinor:3;CInfoOSSP:0;CInfoOSArchitecture:x64;
    // CommandData RDPFile:NotFound;
    // DataFileName
    OutData.CommandStr:='TSCAClient:ClientDataChecked';

    if GetFindStringParams(InData.CommandData,'RDPFile')='NotFound' then
    begin
       SetLog('RDPFile NotFound');
       OutData.CommandParameters:='State:SendingRDPSettins';

     if StrToInt(GetFindStringParams(InData.CommandParameters,'CInfoOSMajor')) < 6  then
      begin
      // Xp
        SetLog('CInfoOSMajor < 6');
        OutData.CommandData:=OutData.CommandData+'RDPFileRequired:Yes;RDPFileName:RDS_Profile01.RDP;';
        OutData.CommandData:=OutData.CommandData+'Cert:NotRequired;';
        OutData.CommandData:=OutData.CommandData+'RDPGate:No;';
        OutData.CommandData:=OutData.CommandData+'RDPNamePost:33892;';
        OutData.CommandData:=OutData.CommandData+'RDPID:001;';
        OutData.DataFileName:=OutData.DataFileName+'RDS_Profile01.RDP;';
      end;
      if StrToInt(GetFindStringParams(InData.CommandParameters,'CInfoOSMajor')) > 5  then
      begin
      // Vista
        SetLog('CInfoOSMajor > 5');
        OutData.CommandData:=OutData.CommandData+'RDPFileRequired:Yes;RDPFileName:RDS_Profile02.RDP;';
        OutData.CommandData:=OutData.CommandData+'CertRequired:Yes;CertName:'+IniFileRead('CertName')+';CertSn:'+IniFileRead('CertSn')+';' ;
        OutData.CommandData:=OutData.CommandData+'RDPGate:Yes;';     //--------------------
        OutData.CommandData:=OutData.CommandData+'RDPNamePost:A16-RDB.ALM.LOCAL;';
        OutData.CommandData:=OutData.CommandData+'RDPID:002;';
        OutData.DataFileName:=OutData.DataFileName+'RDS_Profile02.RDP;'+IniFileRead('CertName')+';';
      end;
      OutData.CommandData:=OutData.CommandData+'RDPDomain:'+IniFileRead('RDPDomain')+';';
    end;

    if GetFindStringParams(InData.CommandData,'RDPFile')='Yes' then
    begin
      //

    end;

    if GetFindStringParams(InData.CommandData,'RemoteAssistantFile')='NotFound' then
    begin
      OutData.CommandData:=OutData.CommandData+'RemoteAssistantRequired:Yes;RemoteAssistantFileName:'+IniFileRead('RemoteAssistantFileName')+';' ;
      OutData.DataFileName:=OutData.DataFileName+IniFileRead('RemoteAssistantFileName')+';';
    end;

    if GetFindStringParams(InData.CommandData,'RemoteAssistantLink')='NotFound' then
    begin
      OutData.CommandData:=OutData.CommandData+'RemoteAssistantLinkRequired:Yes;RemoteAssistantLinkFileName:'+IniFileRead('RemoteAssistantLinkFileName')+';' ;
      OutData.DataFileName:=OutData.DataFileName+IniFileRead('RemoteAssistantLinkFileName')+';';
    end;

  end;

  SetLog('Сформированны данные '+OutData.CommandStr+' : '+OutData.CommandParameters+' : '+OutData.CommandData+' : '+OutData.DataFileName);
  Result:=OutData;
end;

procedure SetLog(TextLog:string);
var
  LogFile: TextFile;
  LogLevel:string;
  NameLogFile:String;
begin
  NameLogFile:='';
  LogLevel:=Trim(IniFileRead('LogLevel')) ;
  if LogLevel = 'LogOn' then
  begin
    CS_SetLog.Enter;
    if TDirectory.Exists(PathHomeProgramm+'Logs\')=False then TDirectory.CreateDirectory(PathHomeProgramm+'Logs\');
    AssignFile(LogFile, PathHomeProgramm+'Logs\TSCAServerLog_'+FormatDateTime('yyyy-mm-dd',Now)+'.txt');
    if FileExists(PathHomeProgramm+'Logs\TSCAServerLog_'+FormatDateTime('yyyy-mm-dd',Now)+'.txt')=False then
    begin
      ReWrite(LogFile);
      CloseFile(LogFile);
    end;
    Append(LogFile);
    WriteLn(LogFile,FormatDateTime('yyyy-mm-dd hh:nn:ss',Now)+' [TSCA Server] > '+TextLog);
    CloseFile(LogFile);
    CS_SetLog.Leave;
  end;
end;

procedure TLanServerEvent.LanServerConnected(AContext: TIdContext);
begin
  SetLog('LanClientConnected');
end;

procedure TLanServerEvent.LanServerDisconnected(AContext: TIdContext);
begin
  SetLog('LanClientDisconnected');
end;

procedure TLanServerEvent.LanServerExecute(AContext: TIdContext);
var
  LanDataPackageSending,LanDataPackageReceiving:TLanDataPackage;
  SendingDataStream: TMemoryStream;
begin
  SetLog('LanClientExecute In');
  try
    SetLog('Под готовка к получению данных');
    SendingDataStream:=TMemoryStream.Create ;
    try
      AContext.Connection.IOHandler.ReadStream(SendingDataStream, -1, False);
      LoadDataFromStream(SendingDataStream,LanDataPackageReceiving);
      SetLog('Обьем Record '+IntToStr(SizeOf(LanDataPackageReceiving)));
      SetLog('Обьем Stream '+IntToStr(SendingDataStream.Size));
    finally
      FreeAndNil(SendingDataStream);
    end;
    SetLog('Данные получены');
  except
    on E: Exception do SetLog('Ошибка получения данных '+E.ClassName + ': ' + E.Message);
  end;
  sleep(500);
  SetLog('Данные получены CommandStr '+LanDataPackageReceiving.CommandStr+' CommandParameters '+LanDataPackageReceiving.CommandParameters+' CommandData '+LanDataPackageReceiving.CommandData+' DataFileName '+LanDataPackageReceiving.DataFileName);
  SetLog('Подготовка к отправке данных');
  LanDataPackageSending:=GetResponseData(LanDataPackageReceiving);
  try
    SetLog('Под готовка к передаче данных');
    SetLog('Передача Record '+LanDataPackageSending.CommandStr);
    SetLog('Передача Record '+LanDataPackageSending.CommandParameters);
    SetLog('Передача Record '+LanDataPackageSending.CommandData);
    SetLog('Передача Record '+LanDataPackageSending.DataFileName);
    SendingDataStream:=TMemoryStream.Create;
    try
      SaveDataToStream(LanDataPackageSending,SendingDataStream);
      SetLog('Обьем Record '+IntToStr(SizeOf(LanDataPackageSending)));
      SetLog('Обьем Stream '+IntToStr(SendingDataStream.Size));
      AContext.Connection.IOHandler.Write(SendingDataStream, 0, True);
    finally
      FreeAndNil(SendingDataStream);
    end;
    SetLog('Данные переданы');
  except
    on E: Exception do SetLog('Ошибка передачи данных '+E.ClassName + ': ' + E.Message);
  end;
  sleep(1000);
end;

function GetFindStringParams(SourceString: string; ParamsName:string):String;
var
  i,StringCountTmp:integer;
begin
  Result:='';
  StringCountTmp:=GetParseStringCount(SourceString);
  if StringCountTmp > 0 then
  begin
    for I :=0  to StringCountTmp do
    begin
      if ParamsName=GetParseParameter(GetParseStringParams(SourceString, i),0) then
      begin
        Result:=GetParseParameter(GetParseStringParams(SourceString, i),1)
      end;
    end;
  end;
end;

function GetParseStringParams(SourceString: string; NumberParameter:integer):String;
var
  i:integer;
  StringTemp:string;
begin
  // Формат строки Param01:Value01;Param02:Value02;
  if (Length(SourceString)>0) and
     (Pos(';',SourceString)>0) and
     (NumberParameter <= GetParseStringCount(SourceString)) and
     (GetParseStringCount(SourceString)>0) and
     (NumberParameter>=0)  then
  begin
    for I := 0 to GetParseStringCount(SourceString)-1 do
    begin
      StringTemp :=Copy(SourceString,1,Pos(';',SourceString)-1);
      Delete(SourceString,1,Length(StringTemp)+1);
      if i=NumberParameter then
      begin
        Result :=StringTemp;
        break;
      end;
    end;
  end
  else
  begin
    Result :='';
  end;
end;

function GetParseStringCount(SourceString: string):Integer;
var
  i,ParamCount:integer;
begin
  ParamCount:=0;
  if (Length(SourceString)>0) and (Pos(';',SourceString)>0) then
  begin
    for I := 1 to Length(SourceString) do if SourceString[i] = ';' then inc(ParamCount);
    Result:=ParamCount;
  end
  else
  begin
    Result:=0;
  end;
end;

function GetParseParameter(SourceString: string; ReturnValue:integer):String;
begin
  if (Length(SourceString)>0) and
     (Pos(':',SourceString)>0) and
     (ReturnValue<2) and
     (ReturnValue>-1)then
  begin
    if ReturnValue=0 then Result :=Copy(SourceString,1,Pos(':',SourceString)-1);
    if ReturnValue=1 then Result :=Copy(SourceString,Pos(':',SourceString)+1,Length(SourceString)-Pos(':',SourceString));
  end
  else
    Result:='';
end;

initialization
 CS_SetLog:= TCriticalSection.Create;
 {здесь располагается код инициализации}

finalization
 CS_SetLog.Free;
 {здесь располагается код финализации}

end.
