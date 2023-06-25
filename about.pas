unit about;

{$mode ObjFPC}{$H+}

interface

uses
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
	Buttons, DateUtils, Math;

type

	{ TAboutWindow }

 TAboutWindow = class(TForm)
		CloseButton: TButton;
		VersionNumber: TLabel;
		RPNLogo: TImage;
		Heading: TLabel;
		DateOfBuild: TLabel;
		procedure CloseButtonClick(Sender: TObject);
  procedure FormCreate(Sender: TObject);
	private

	public

	end;

var
	AboutWindow: TAboutWindow;

implementation

{$R *.lfm}

{ TAboutWindow }

{$WARNING Make sure to change RPN_TZ to be your local timezone offset.}
{$WARNING RPN_TZ is set in Project Options>Compiler Options>Custom Options.}
{The build number is yyyy-mm-dd.ff, where ff is the fractional day}
procedure TAboutWindow.FormCreate(Sender: TObject);
var
	BuildDate: TDateTime;
	BuildStr: AnsiString;
	FractionalDay: AnsiString;
	TZOffset: Integer;
begin
	TZOffset := RPN_TZ * 60;
	BuildDate := StrToDate({$I %DATE%}, 'YYYY/MM/DD');
	BuildDate += StrToTime({$I %TIME%});
	BuildDate := LocalTimeToUniversal(BuildDate, TZOffset);
	BuildStr := Concat('Build ', FormatDateTime('YYYY-MM-DD', BuildDate));
	BuildDate := BuildDate - Floor(BuildDate);
	FractionalDay := FloatToStrF(BuildDate, ffNumber, -1, 2);
	FractionalDay := Copy(FractionalDay, 2, 3);
	BuildStr := BuildStr + FractionalDay;
{$IFDEF RPN_DEBUG_BUILD}
	BuildStr := BuildStr + ' [debug]';
{$ENDIF}
        DateOfBuild.Caption := BuildStr;
end;

procedure TAboutWindow.CloseButtonClick(Sender: TObject);
begin
	Close;
end;

end.

