unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, Registry,
  Main;

type
  TTSCA_Srv = class(TService)
    procedure ServiceExecute(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceShutdown(Sender: TService);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  TSCA_Srv: TTSCA_Srv;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  TSCA_Srv.Controller(CtrlCode);
end;

function TTSCA_Srv.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TTSCA_Srv.ServiceAfterInstall(Sender: TService);
var
  Service_Description:TRegistry;
begin
  Service_Description:=TRegistry.Create;
  Service_Description.RootKey:=HKEY_LOCAL_MACHINE;
  try
    if Service_Description.OpenKey ('\SYSTEM\CurrentControlSet\Services\TSCA_Srv', true) then
    begin
      if Service_Description.ValueExists ('Description')  then
      begin
        if (Length(trim(Service_Description.ReadString('Description')))=0) then Service_Description.WriteString('Description','Сервер приложения TSCA');
      end
      else
      begin
        Service_Description.WriteString('Description','Сервер приложения TSCA');
      end;
      Service_Description.CloseKey;
    end
  finally
    FreeAndNil(Service_Description);
  end;
end;

procedure TTSCA_Srv.ServiceExecute(Sender: TService);
begin
  Sleep(1000);
  while not Terminated do
  begin
    ServiceThread.ProcessRequests(true);
    Sleep(1000);
  end;
end;

procedure TTSCA_Srv.ServiceShutdown(Sender: TService);
begin
  TSCAServerStop;
end;

procedure TTSCA_Srv.ServiceStart(Sender: TService; var Started: Boolean);
begin
  Started:=True;
  TSCAServerStart;
end;

procedure TTSCA_Srv.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  TSCAServerStop;
  Stopped:=True;
end;

end.
