unit Main;

interface
uses
  Winapi.ShellAPI, System.SysUtils, System.IOUtils, System.Classes, IdContext,
  ExtUnit;

procedure TSCAServerStart;
procedure TSCAServerStop;

var
  PathHomeProgramm,PathExchangeFolder:string;

implementation

procedure TSCAServerStart;
begin
  PathHomeProgramm:= Trim(ExtractFilePath(paramstr(0)));
  PathExchangeFolder:='ExcangeFiles\';
  if TDirectory.Exists(PathHomeProgramm+PathExchangeFolder)=False then TDirectory.CreateDirectory(PathHomeProgramm+PathExchangeFolder);
  if IniFileRead('Server Init') = '' then
  begin
    IniFileWrite('Server Init','On') ;
    IniFileWrite('ClientVersion','0') ;
    IniFileWrite('LogLevel','LogOff') ;
    IniFileWrite('CertSn','') ;
  end;
  SetLog('Запуск Сервера');
  try
    LanServerEvent:=TLanServerEvent.Create;
    LanServer:=TLanServer.Create;
    LanServer.OnExecute:=LanServerEvent.LanServerExecute;
    LanServer.OnConnect:=LanServerEvent.LanServerConnected;
    LanServer.OnDisconnect:=LanServerEvent.LanServerDisconnected;
    try
      if IniFileRead('Server_Port') <> '' then LanServer.DefaultPort:=StrToInt(IniFileRead('Server_Port'));
    except
      LanServer.DefaultPort:=30380;
    end;
    LanServer.Active:=true;
    SetLog('Сервер - Запущен ');
  except
    on E: Exception do SetLog('Сервер - Ошибка запуска сервера '+E.ClassName + ': ' + E.Message);
  end;

end;

procedure TSCAServerStop;
var
  List:Tlist;
  i:integer;
begin
  try
    try
      List := LanServer.Contexts.LockList;
      SetLog('Сервер - Конектов ' + IntToStr(List.Count))  ;
      for i := 0 to List.Count - 1 do
      begin
        TIdContext(List.Items[i]).Connection.Disconnect;
        TIdContext(List.Items[i]).Connection.Socket.Close;    //Работает при x32
       // TIdContext(List.Items[i]).Connection.IOHandler.Free;
      end;
      SetLog('Сервер - Конекты отключены')
    finally
      LanServer.Contexts.UnlockList;
      sleep(500);
      LanServer.Scheduler.ActiveYarns.Clear;
      LanServer.Bindings.Clear;
      LanServer.Active := False;

    end;
  except
    on E: Exception do SetLog('Сервер - Ошибка остановки сервера '+E.ClassName + ': ' + E.Message);
  end;
  FreeAndNil(LanServer);
  FreeAndNil(LanServerEvent);
  SetLog('Остановка сервера ');
end;

end.
