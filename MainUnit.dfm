object TSCA_Srv: TTSCA_Srv
  OldCreateOrder = False
  AllowPause = False
  DisplayName = 'TSCA '#1057#1077#1088#1074#1077#1088' '
  AfterInstall = ServiceAfterInstall
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
