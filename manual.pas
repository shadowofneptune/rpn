unit manual;

{$mode ObjFPC}{$H+}

interface

uses
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids,
	ComCtrls, ExtCtrls, LazHelpHTML, RichMemo, Types;

type

	{ TManualWindow }

 TManualWindow = class(TForm)
	 BUMemo: TRichMemo;
	 AdvancedMemo: TRichMemo;
	 OperatorListContent: TListView;
	 TabBar: TPageControl;
	 BasicUsage: TTabSheet;
	 Advanced: TTabSheet;
	 OperatorList: TTabSheet;
	end;

var
	ManualWindow: TManualWindow;

implementation

{$R *.lfm}

end.
