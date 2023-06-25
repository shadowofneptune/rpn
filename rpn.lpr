program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, datetimectrls, main, manual, about;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
	Application.Title:='RPN Calculator';
	Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainWindow, MainWindow);
	Application.CreateForm(TManualWindow, ManualWindow);
	Application.CreateForm(TAboutWindow, AboutWindow);
  Application.Run;
end.

