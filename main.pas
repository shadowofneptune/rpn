unit main;

{$mode objfpc}{$H+}
{$inline on}
{$WARN 5024 off : Parameter "$1" not used}
interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, StdCtrls,
  ComCtrls, ExtCtrls, RegExpr, LCLType, Math, Types, StrUtils, LResources,
  ActnList, Character, manual, about;

type

  { TMainWindow }

	TMainWindow = class(TForm)
		FileOpen: TMenuItem;
		MenuHelp: TMenuItem;
		FileRecord: TMenuItem;
		MainMenu: TMainMenu;
		MenuFile: TMenuItem;
		FileQuit: TMenuItem;
		FileDiscard: TMenuItem;
		FileSave: TMenuItem;
		HelpDict: TMenuItem;
		HelpAbout: TMenuItem;
		OpenTranscriptDialog: TOpenDialog;
        	ExecuteButton: TButton;
		ErrorImages: TImageList;
		Prompt: TEdit;
		SaveTranscriptDialog: TSaveDialog;
		StackList: TListBox;
		StatusBar: TStatusBar;
		procedure SkipComment(
                        var Tokens: TStringDynArray;
                        var i: Integer
		);
		procedure DiscardTranscriptDialogButtonClicked(
                        Sender: TObject;
  			AModalResult: TModalResult;
                        var ACanClose: Boolean
		);
		procedure FileDiscardClick(Sender: TObject);
		procedure FileOpenClick(Sender: TObject);
		procedure FileQuitClick(Sender: TObject);
		procedure FileRecordClick(Sender: TObject);
		procedure FileSaveClick(Sender: TObject);
		procedure HelpAboutClick(Sender: TObject);
		procedure HelpDictClick(Sender: TObject);
		procedure StatusBarDrawPanel(
			SBar: TStatusBar;
			Panel: TStatusPanel;
			const Rect: TRect
		);
		procedure UpdateStackList;
		procedure ShowErrorMessage;
		procedure PromptParse(PromptText: AnsiString);
		procedure ExecuteButtonClick(Sender: TObject);
		procedure PromptExecute(
			Sender: TObject;
			var Key: Word;
			Shift: TShiftState
		);
	end;

var
	MainWindow: TMainWindow;

implementation

type
        {'Code' is an OperationDyn, in truth. It has to be cast to a pointer
         to get around the limitations of the type system.
        }

	Operation = procedure(
		var Code: Pointer;
        	var CodeIndex: Integer
	);
	OperationDyn = array of Operation;

	ErrorType = (Success, Partial, Total);

{$if defined(CPU32)}
	RpnFloat = Single;
{$elseif defined(CPU64)}
	RpnFloat = Double;
{$else}
	{$error RpnFloat must be same size as a pointer.}
{$endif}

const
StackSize = $80;

var

ErrorMessage: AnsiString = '';
ErrorStatus: ErrorType;
Stack: array [1..StackSize] of Double;
StackPointer: Integer = 0;
Recording: Boolean = False;
TranscriptRecord: AnsiString = '';

{$R *.lfm}

procedure Push(x: Double);
inline;
begin
	if (StackPointer >= 0) and (StackPointer < StackSize) then begin
		StackPointer += 1;
		Stack[StackPointer] := x;
	end;
end;

function Pop: Double;
inline;
begin
	if (StackPointer >= 1) and (StackPointer <= StackSize) then begin
		Result := Stack[StackPointer];
		StackPointer -= 1;
	end else begin
		Result := 0.0;
	end;
end;

{An operation was invalid, but parsing can continue. Shows a yellow mark on
 the status bar.
}
procedure PartialError(Message: AnsiString);
begin
	ErrorMessage := Message;
	ErrorStatus := Partial;
end;

{A word was not found, but parsing can continue. Shows a yellow mark on
 the status bar.
}
procedure NotFoundError(Message: AnsiString);
begin
	ErrorMessage := '"' + Message + '" not found.';
	ErrorStatus := Partial;
end;

{An operation was invalid, and  parsing cannot continue. Shows a red mark on
 the status bar.
}
procedure TotalError(Message: AnsiString);
begin
	ErrorMessage := Message;
	ErrorStatus := Total;
end;

function Peek: Double;
inline;
begin
	Result := Stack[StackPointer];
end;

function Peek(Index: Integer): Double;
inline;
begin
	Result := Stack[StackPointer - Index];
end;

procedure IPlus(var Code: Pointer; var CodeIndex: Integer);
begin
	if StackPointer >= 2 then
		Push(Pop + Pop)
	else
		PartialError('+ needs two operands.');
end;

procedure IMinus(var Code: Pointer; var CodeIndex: Integer);
var
	x, y: Double;
begin
	if StackPointer >= 2 then begin
		y := Pop; x := Pop;
		Push(x - y);
	end else begin
		PartialError('- needs two operands.');
	end;
end;

procedure IMul(var Code: Pointer; var CodeIndex: Integer);
begin
	if StackPointer >= 2 then
		Push(Pop * Pop)
	else
		PartialError('* needs two operands.');
end;

procedure IDiv(var Code: Pointer; var CodeIndex: Integer);
var
	x, y: Double;
begin

	if StackPointer >= 2 then begin
		if Peek <> 0.0 then begin
			y := Pop; x := Pop;
			Push(x / y);
		end else begin
			PartialError('Division by 0.');
		end;
	end else begin
		PartialError('/ needs two operands.');
	end;
end;

procedure IRem(var Code: Pointer; var CodeIndex: Integer);
var
	x, y: Double;
begin

	if StackPointer >= 2 then begin
		if Peek <> 0.0 then begin
			y := Pop; x := Pop;
			Push(x mod y);
		end else begin
			PartialError('Division by 0.');
		end;
	end else begin
		PartialError('% needs two operands.');
	end;
end;

procedure IMod(var Code: Pointer; var CodeIndex: Integer);
var
	x, y: Double;
begin

	if StackPointer >= 2 then begin
		if Peek <> 0.0 then begin
			y := Pop; x := Pop;
			Push(x - Math.Floor(x / y) * y);
		end else begin
			PartialError('Division by 0.');
		end;
	end else begin
		PartialError('% needs two operands.');
	end;
end;

procedure IExp(var Code: Pointer; var CodeIndex: Integer);
begin
	if StackPointer >= 2 then
		Push(Power(Pop,Pop))
	else
		PartialError('^ needs two operands.');
end;

procedure IDrop(var Code: Pointer; var CodeIndex: Integer);
begin
	if StackPointer > 0 then
		Pop
	else
		PartialError('"drop" needs an operand.');
end;

procedure IDup(var Code: Pointer; var CodeIndex: Integer);
begin
       if StackPointer > 0 then
	Push(Peek)
	else
	PartialError('"dup" needs an operand.');
end;

procedure I2Dup(var Code: Pointer; var CodeIndex: Integer);
begin
	if StackPointer >= 2 then begin
		Push(Peek(1));
       		Push(Peek(1));
	end else begin
	       	PartialError('"2dup" needs an operand.');
	end;
end;

procedure ISwap(var Code: Pointer; var CodeIndex: Integer);
var
	x, y: Double;
begin
       	if StackPointer >= 2 then begin
		y := Pop; x := Pop;
       		Push(y); Push(x);
	end else begin
               	PartialError('"swap" needs two operands.');
	end;
end;

procedure IRot(var Code: Pointer; var CodeIndex: Integer);
var
	x, y, z: Double;
begin
       	if StackPointer >= 2 then begin
		y := Pop; x := Pop; z := Pop;
       		  Push(y); Push(z); Push(x);
	end else begin
               	PartialError('"rot" needs three operands.');
	end;
end;

procedure ILog(var Code: Pointer; var CodeIndex: Integer);
begin
       	if StackPointer > 0 then
		Push(Log10(Pop))
	else
               	PartialError('"log" needs an operand.');
end;

procedure ILn(var Code: Pointer; var CodeIndex: Integer);
begin
       	if StackPointer > 0 then
		Push(Ln(Pop))
	else
               	PartialError('"ln" needs an operand.');
end;

procedure ISqrt(var Code: Pointer; var CodeIndex: Integer);
begin
       	if StackPointer > 0 then
		Push(Sqrt(Pop))
	else
               	PartialError('"sqrt" needs an operand.');
end;

{Makes it possible to embed numbers in an OperationDyn. The next entry after
 ILit is always an RPNFloat casted to a function pointer.
 Not accessible to the user.
}
procedure ILit(var Code: Pointer; var CodeIndex: Integer);
var
	c: OperationDyn;
begin;
	c := OperationDyn(Code);
	CodeIndex += 1;
	Push(RpnFloat(c[CodeIndex]));
end;

{As simple as Pi}
procedure IPi(var Code: Pointer; var CodeIndex: Integer);
begin;
	Push(Pi);
end;


var

	{Dictionary (its fields start with D): Contain intrinsic operations
	 and macros added at runtime.
	}
	DCode: array of array of Operation = (
		(@IPlus),
		(@IMinus),
		(@IMul),
		(@IDiv),
		(@IRem),
		(@IMod),
		(@IExp),
		(@IDrop),
		(@IDup),
		(@I2Dup),
		(@ISwap),
		(@IRot),
		(@ILog),
		(@ILn),
		(@ISqrt),
		(@IPi)
	);
        DName: array of AnsiString = (
        	'+', {plus}
        	'-', {minus}
        	'*', {mul}
        	'/', {div}
        	'%', {remainder}
        	'mod', {modulo}
        	'^', {exponentiation}
        	'drop', {drop value}
        	'dup', {duplicate value}
        	'2dup', {duplicate top two values}
        	'swap', {swap top two values}
        	'rot', {rotates top three values}
        	'log',
        	'ln',
        	'sqrt',
        	'pi' {Pi}
        );

{ TMainWindow }

{Redraws the stack diagram.}
procedure TMainWindow.UpdateStackList;
var
	i: Integer;
begin
	StackList.Items.Clear();
	if StackPointer > 0 then begin
		for i := StackPointer downto 1 do
			StackList.Items.Add(FloatToStr(Stack[i]));
	end;
end;

{Finds an entry in the dictionary based on its Name. Returns the index
 into the dictionary, or -1 if no match is found.
}
function FindWord(var Name: AnsiString): Integer
inline;
var
	i: Integer;
begin
	Result := -1;
	for i := High(DName) downto Low(DName) do begin
		if CompareStr(Name, DName[i]) = 0 then begin
			Result := i;
                        break;
		end;
	end;
end;

{Compiles user-defined operations, also known as words or macros.

 The start of this function performs basic validation. There should be at least
 three tokens left, and someone shouldn't do something silly like redefine
 [ to be 1.

 If an encountered token is a word, that word's code is concatenated
 onto the new word. If it's a number, the special Lit operator is
 placed onto it, followed by the number's bit pattern.
}
procedure CompileWord(var Tokens: TStringDynArray; var i: Integer);
var
	Word: OperationDyn;
	Match: Integer;
	r: RpnFloat;
	WordName: String;
begin
	if i + 3 > High(Tokens) then begin
		TotalError('Macro is incomplete.');
		i := High(Tokens) + 1;
        	Exit;
	end;
	i += 1;
	if CompareStr(Tokens[i], ']') = 0 then begin
		TotalError('Macro is incomplete.');
		i := High(Tokens) + 1;
        	Exit;
	end;
	if CompareStr(Tokens[i], '[') = 0 then begin
		TotalError('Macro definitions cannot be nested.');
		i := High(Tokens) + 1;
                Exit;
	end;

	WordName := Tokens[i];

	i += 1;
	Word := OperationDyn.Create;
	while i < High(Tokens) do begin
		if CompareStr(Tokens[i], ']') = 0 then
			break;

        	if CompareStr(Tokens[i], '[') = 0 then begin
        		TotalError('Macro definitions cannot be nested.');
        		i := High(Tokens) + 1;
                        Exit;
        	end;
		Match := FindWord(Tokens[i]);

		if Match <> -1 then begin
			Word := Concat(Word, DCode[Match]);
		end else begin
			if TryStrToFloat(Tokens[i], r) = True then begin
				Word := Concat(Word, [@ILit]);
				Word := Concat(Word, [Operation(r)]);
			end else begin
				NotFoundError(Tokens[i]);
			end;
		end;
		i += 1;
	end;

        DName := Concat(DName, [WordName]);
	DCode := Concat(DCode, [Word]);
end;

{Displays the current error message, then discards the old one.}
procedure TMainWindow.ShowErrorMessage;
begin
	StatusBar.Panels[1].Text := ErrorMessage;
	ErrorMessage := '';
	StatusBar.Invalidate;
end;

{Executes operations, also known as words.

 If the token is a word, the code of that word is executed. If it is a number,
 the number is pushed onto the stack.
}

procedure ExecuteWord(var Tokens: TStringDynArray; var i: Integer);
var
	j, Match: Integer;
	r: RpnFloat;
	Code: Pointer;
begin
	Match := FindWord(Tokens[i]);

	if Match <> -1 then begin
		j := Low(DCode[Match]);
		while j <= High(DCode[Match]) do
                begin
			Code := Pointer(DCode[Match]);
			Dcode[Match][j](Code, j);
			j += 1;
		end;
	end else begin
		if TryStrToFloat(Tokens[i], r) = True then
			Push(r)
		else
			NotFoundError(Tokens[i]);
	end;
end;

procedure TMainWindow.SkipComment(var Tokens: TStringDynArray; var i: Integer);
begin
	while i <= High(Tokens) do begin
		if CompareStr(Tokens[i], '}') = 0 then
			break;
		i += 1;
	end;
end;

{Tokenizes the user's prompt, then begins interpreting its contents. The
 special token '[' indicates that the user wants to compile a custom word.
 Any other words are executed.
}
procedure TMainWindow.PromptParse(PromptText: AnsiString);
var
	i: Integer;
	Tokens: TStringDynArray;
begin
	if Recording = True then
		TranscriptRecord += LineEnding + PromptText;

	for i := Low(PromptText) to High(PromptText) do begin
		if IsWhiteSpace(PromptText[i]) then
			PromptText[i] := ' ';
	end;
	Tokens := SplitString(PromptText, ' ');

	i := Low(Tokens);
	while i <= High(Tokens) do begin
		if Length(Tokens[i]) > 0 then begin
			Tokens[i] := LowerCase(Tokens[i]);
			if CompareStr(Tokens[i], '[') = 0 then
				CompileWord(Tokens, i)
			else if CompareStr(Tokens[i], '{') = 0 then
				SkipComment(Tokens, i)
			else
				ExecuteWord(Tokens, i);
		end;
		i += 1;
	end;
	UpdateStackList;
	ShowErrorMessage;
end;

{Fired when the user hits a key on the keyboard while the prompt is selected.}
procedure TMainWindow.PromptExecute(
  	Sender: TObject;
	var Key: Word;
	Shift: TShiftState
);
begin
 	if (Key = VK_RETURN) and (Length(Prompt.Text) > 0)
        	then PromptParse(Prompt.Text);
end;

{Fired when the user hits the '=' button.}
procedure TMainWindow.ExecuteButtonClick(Sender: TObject);
begin
	if Length(Prompt.Text) > 0 then PromptParse(Prompt.Text);
end;

procedure TMainWindow.StatusBarDrawPanel(
        SBar: TStatusBar;
	Panel: TStatusPanel;
        const Rect: TRect
);
var
	DrawPos: Integer;
begin
	DrawPos := (Sbar.Canvas.Height - ErrorImages.Height) div 2;
	ErrorImages.Draw(SBar.Canvas, DrawPos, DrawPos, Integer(ErrorStatus));
	ErrorStatus := Success;
end;

procedure TMainWindow.FileQuitClick(Sender: TObject);
begin
	Halt;
end;

procedure TMainWindow.FileRecordClick(Sender: TObject);
begin
        if Recording = False then begin
		Recording := True;
		FileRecord.Checked := True;
		ErrorMessage := 'Recording transcript...';
	end else begin
		Recording := False;
		FileRecord.Checked := False;
		ErrorMessage := 'Stopped recording.';
	end;
	ShowErrorMessage;
end;

procedure TMainWindow.FileSaveClick(Sender: TObject);
var
	f: TStringList;
begin
        SaveTranscriptDialog.Execute;
	f := TStringList.Create;
	f.Append(TranscriptRecord);
	if Length(SaveTranscriptDialog.FileName) > 0 then
		f.SaveToFile(SaveTranscriptDialog.FileName);
	f.Free;
end;

procedure TMainWindow.HelpAboutClick(Sender: TObject);
begin
         AboutWindow.Show;
end;

procedure TMainWindow.HelpDictClick(Sender: TObject);
begin
        ManualWindow.Show;
end;

procedure TMainWindow.FileOpenClick(Sender: TObject);
var
	f: TStringList;
begin
        OpenTranscriptDialog.Execute;
	f := TStringList.Create;
	f.LineBreak := '';
	if Length(OpenTranscriptDialog.FileName) > 0 then
		f.LoadFromFile(OpenTranscriptDialog.FileName);
	PromptParse(f[0]);
	f.Free;
end;


procedure TMainWindow.FileDiscardClick(Sender: TObject);
begin
        if Dialogs.MessageDlg(
        	'Do you want to discard the transcript?',
		mtConfirmation,
                [mbYes, mbNo],
                0,
                mbYes
	) = mrYes then
		TranscriptRecord := '';
end;

procedure TMainWindow.DiscardTranscriptDialogButtonClicked(Sender: TObject;
	AModalResult: TModalResult; var ACanClose: Boolean);
begin

end;


end.
