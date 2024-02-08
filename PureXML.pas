unit PureXML;

interface

uses
  Types, Windows, Messages, SysUtils, Variants, Classes;

type
  TNodeType = (ntReserved, ntElement, ntAttribute, ntText, ntCData,
    ntEntityRef, ntEntity, ntProcessingInstr, ntComment, ntDocument,
    ntDocType, ntDocFragment, ntNotation);

  IXMLNodeList = class;

  IXMLNode = class
  protected
    FName: String;
    FDataStart: Integer;
    FIsClosed: Boolean;
    FParent: IXMLNode;
    FNodes: IXMLNodeList;
    FAttributes: TStringList;
    FValue: Variant;
  public
    NodeType: TNodeType;

    constructor Create(aParent: IXMLNode; aNodeType: TNodeType);
    destructor Destroy; override;

    function AddChild(Name: String): IXMLNode;
    function Attributes(Name: String): String; overload;
    procedure Attributes(Name: String; Value: Variant); overload;
    function ChildNodes: IXMLNodeList; overload;
    function ChildNodes(Index: Integer): IXMLNode; overload;
    function ChildNodes(Name: String): IXMLNode; overload;
    function ChildValues(Name: String): Variant; overload;
    procedure ChildValues(Name: String; Value: Variant); overload;
    function CloneNode(Deep: Boolean): IXMLNode;
    function HasAttribute(Name: String): Boolean;

    property NodeValue: Variant read FValue write FValue;
    property NodeName: String read FName;
  end;

  IXMLNodeList = class(TList)
  protected
    FOwner: IXMLNode;
    function Get(Index: Integer): IXMLNode;
    procedure Put(Index: Integer; Node: IXMLNode);
  public
    constructor Create(Owner: IXMLNode);
    destructor Destroy; override;

    function Add(Item: IXMLNode): Integer;
    function FindNode(Name: String): IXMLNode;
    function Remove(Item: IXMLNode): Integer;
    function RemoveAndFree(Item: IXMLNode): Integer;

    property Items[Index: Integer]: IXMLNode read Get write Put; default;
  end;

  TXMLDocument = class
  protected
    FslXML: TStringList;
    FXML: IXMLNode;
    FTab: String;

    function AttributesToString(Node: IXMLNode): String;
    procedure AddNodesToFile(Nodes: IXMLNodeList; ParentTab: String);
    procedure BuildTextFile;
    procedure BuildXmlTree;
  public
    function ChildNodes: IXMLNodeList; overload;
    function ChildNodes(Index: Integer): IXMLNode; overload;
    function ChildNodes(Name: String): IXMLNode; overload;

    constructor Create(Owner: TObject);
    destructor Destroy; override;
    procedure LoadFromFile(FileName: String);
    procedure SaveToFile(FileName: String);
  end;


implementation

uses
  StrToolz;

const
  EMPTY_STRING = #0;


procedure AddAttributes(Node: IXMLNode; Data: String);
var
  name, value: string;
begin
  repeat
    name := GetNextFromStr(Data, '"');
    name := StringReplace(name, '=', '', []);
    name := StringReplace(name, ' ', '', [rfReplaceAll]);
    value := GetNextFromStr(Data, '"');

    if value = '' then
      value := EMPTY_STRING;

    Node.FAttributes.Values[name] := value;
  until Pos('"', Data) < 1;
end;

function AddNode(Data: String; DataStart: Integer; Parent: IXMLNode; NodeType: TNodeType): IXMLNode;
var
  i: Integer;
  Name: string;
begin
  Data := Trim(Data);

  while Pos('  ', Data) > 0 do
    Data := StringReplace(Data, '  ', ' ', [rfReplaceAll]);//}

  Result := IXMLNode.Create(Parent, NodeType);
  Result.FDataStart := DataStart;

  if NodeType <> ntElement then
  begin
    Result.FName := Data;
    Parent.FNodes.Add(Result);
    Exit;
  end;

  Delete(Data, 1, 1); // skip <
  Delete(Data, Length(Data), 1); // skip >

  if Data[Length(Data)] = '/' then
  begin
    Result.FIsClosed := True;
    Delete(Data, Length(Data), 1); // skip /
  end
  else
    Result.FIsClosed := False;

  Data := Trim(Data);
  Name := Data;

  i := Pos(' ', Name);
  if i > 0 then
    SetLength(Name, i - 1);

  Result.FName := Trim(Name);

  if i > 0 then // Attributes
  begin
    Delete(Data, 1, i);
    Data := Trim(Data);
    AddAttributes(Result, Data);
  end;

  Parent.FNodes.Add(Result);
end;

function GetCloseName(Name: String): String;
begin
  Result := StringReplace(Name, '<', '', []);
  Result := StringReplace(Result, '>', '', []);
  Result := Trim(StringReplace(Result, '/', '', []));
end;

procedure GetStartEnd(var Text, Match: String; var iStart, iEnd: Integer);
begin
  iStart := Pos('<', Text, iEnd);
  iEnd := Pos('>', Text, iStart);
  if (iEnd > 0) and (iStart > 0) then
    Match := Copy(Text, iStart, iEnd - iStart + 1);
end;


{ TXMLDocument }

function TXMLDocument.AttributesToString(Node: IXMLNode): String;
var
  i: Integer;
  Value: string;
begin
  Result := '';

  for i := 0 to Node.FAttributes.Count - 1 do
  begin
    Value := StringReplace(Node.FAttributes.ValueFromIndex[i], '"', '&quot;', [rfReplaceAll]);
    Value := StringReplace(Value, '<', '&lt;', [rfReplaceAll]);
    Value := StringReplace(Value, '<', '&gt;', [rfReplaceAll]);
    Value := StringReplace(Value, EMPTY_STRING, '', [rfReplaceAll]);
    Result := Result + ' ' + Node.FAttributes.Names[i] + '="' + Value + '"';
  end;
end;

procedure TXMLDocument.AddNodesToFile(Nodes: IXMLNodeList; ParentTab: String);
var
  i: Integer;
begin
  for i := 0 to Nodes.Count - 1 do
  begin
    if Nodes[i].FNodes.Count > 0 then
    begin
      FslXML.Add(ParentTab + FTab + '<' + Nodes[i].FName + AttributesToString(Nodes[i]) + '>');
      AddNodesToFile(Nodes[i].FNodes, ParentTab + FTab);
      FslXML.Add(ParentTab + FTab + '</' + Nodes[i].FName + '>');
    end
    else
    if Nodes[i].NodeType = ntComment then
      FslXML.Add(ParentTab + Nodes[i].FName)
    else
    if VarToStr(Nodes[i].FValue) <> '' then
      FslXML.Add(ParentTab + FTab + '<' + Nodes[i].FName + AttributesToString(Nodes[i]) + '>' + VarToStr(Nodes[i].FValue) + '</' + Nodes[i].FName + '>')
    else
      FslXML.Add(ParentTab + FTab + '<' + Nodes[i].FName + AttributesToString(Nodes[i]) + ' />');
  end;
end;

procedure TXMLDocument.BuildTextFile;
begin
  FslXML.Add(FXML.FName);

  AddNodesToFile(FXML.FNodes, '');
end;

procedure TXMLDocument.BuildXmlTree;
var
  ParentNode: IXMLNode;
  iStart, iEnd: Integer;
  sXML, Match: string;
begin
  sXML := FslXML.Text;
  iEnd := 1;
  Match := '';

  GetStartEnd(sXML, Match, iStart, iEnd);
  if Match = '' then Exit;

  if AnsiLowerCase(Copy(Match, 1, 5)) = '<?xml' then
    FXML.FName := Match
  else
    iEnd := 1; // subnode, because we do not have the root xml

  ParentNode := FXML;

  while True do
  begin
    GetStartEnd(sXML, Match, iStart, iEnd);
    if (iStart < 1) or (iEnd < 1) then Break;

    if Copy(Match, 1, 4) = '<!--' then // commentary should not contain < or > symbols
      AddNode(Match, iEnd + 1, ParentNode, ntComment)
    else
    if Copy(Match, 1, 2) = '</' then
    begin
      if (ParentNode.FNodes.Count = 0) and (ParentNode.FName = GetCloseName(Match)) then
        ParentNode.FValue := Copy(sXML, ParentNode.FDataStart, iStart - ParentNode.FDataStart);
      ParentNode := ParentNode.FParent;
    end
    else
    begin
      ParentNode := AddNode(Match, iEnd + 1, ParentNode, ntElement);
      if ParentNode.FIsClosed then
        ParentNode := ParentNode.FParent;
    end;

    if not Assigned(ParentNode) then
      Break;
  end;
end;

function TXMLDocument.ChildNodes: IXMLNodeList;
begin
  Result := FXML.ChildNodes;
end;

function TXMLDocument.ChildNodes(Index: Integer): IXMLNode;
begin
  Result := FXML.ChildNodes(Index);
end;

function TXMLDocument.ChildNodes(Name: String): IXMLNode;
begin
  Result := FXML.ChildNodes(Name);
end;

constructor TXMLDocument.Create(Owner: TObject);
begin
  inherited Create;

  FslXML := TStringList.Create;
  FXML := IXMLNode.Create(nil, ntDocument);
  FXML.FName := '<?xml version="1.0" encoding="utf-8"?>';
  FTab := '  ';
end;

destructor TXMLDocument.Destroy;
begin
  FslXML.Free;
  FXML.Free;

  inherited;
end;

procedure TXMLDocument.LoadFromFile(FileName: String);
begin
  FXML.Free;
  FXML := IXMLNode.Create(nil, ntDocument);
  FXML.FName := '<?xml version="1.0" encoding="utf-8"?>';

  FslXML.LoadFromFile(FileName);
  BuildXmlTree;
  FslXML.Clear;
end;

procedure TXMLDocument.SaveToFile(FileName: String);
begin
  BuildTextFile;
  FslXML.SaveToFile(FileName);
  FslXML.Clear;
end;


{ IXMLNode }

function IXMLNode.AddChild(Name: String): IXMLNode;
begin
  Result := IXMLNode.Create(Self, ntElement);
  Result.FName := Name;
  FNodes.Add(Result);
end;

function IXMLNode.Attributes(Name: String): String;
begin
  Result := FAttributes.Values[Name];
  if Result = EMPTY_STRING then
    Result := '';
end;

procedure IXMLNode.Attributes(Name: String; Value: Variant);
var
  i: Integer;
begin
  if VarIsNull(Value) then
  begin
    i := FAttributes.IndexOfName(Name);
    if i > -1 then
      FAttributes.Delete(i);
  end
  else
  begin
    FAttributes.Values[Name] := VarToStr(Value);
    if FAttributes.Values[Name] = '' then
      FAttributes.Values[Name] := EMPTY_STRING;
  end;
end;

constructor IXMLNode.Create(aParent: IXMLNode; aNodeType: TNodeType);
begin
  inherited Create;

  FNodes := IXMLNodeList.Create(Self);
  FAttributes := TStringList.Create;

  FParent := aParent;
  NodeType := aNodeType;
end;

destructor IXMLNode.Destroy;
begin
  FAttributes.Free;
  FNodes.Free;

  inherited;
end;

function IXMLNode.ChildNodes: IXMLNodeList;
begin
  Result := FNodes;
end;

function IXMLNode.ChildNodes(Index: Integer): IXMLNode;
begin
  Result := FNodes[Index];
end;

function IXMLNode.ChildNodes(Name: String): IXMLNode;
begin
  Result := FNodes.FindNode(Name);

  if not Assigned(Result) then
  begin
    Result := IXMLNode.Create(Self, ntElement);
    Result.FName := Name;
    FNodes.Add(Result);
  end;
end;

function IXMLNode.ChildValues(Name: String): Variant;
var
  Node: IXMLNode;
begin
  Node := ChildNodes(Name);
  Result := Node.FValue;
end;

procedure IXMLNode.ChildValues(Name: String; Value: Variant);
var
  Node: IXMLNode;
begin
  Node := ChildNodes(Name);
  Node.FValue := Value;
end;

function IXMLNode.CloneNode(Deep: Boolean): IXMLNode;
var
  i: Integer;
begin
  Result := IXMLNode.Create(Self.FParent, Self.NodeType);
  Result.FName := Self.FName;
  Result.FValue := Self.FValue;
  Result.FAttributes.Text := Self.FAttributes.Text;

  if not Deep then
    Exit;

  for i := 0 to FNodes.Count - 1 do
    Result.FNodes.Add(FNodes[i].CloneNode(True));
end;

function IXMLNode.HasAttribute(Name: String): Boolean;
begin
  Result := FAttributes.IndexOfName(Name) > -1;
end;


{ IXMLNodeList }

function IXMLNodeList.Add(Item: IXMLNode): Integer;
begin
  if Assigned(Item.FParent) and (Item.FParent.FNodes.IndexOf(Item) > -1) then
    Item.FParent.FNodes.Remove(Item);

  Result := inherited Add(Item);
  Item.FParent := FOwner;
end;

constructor IXMLNodeList.Create(Owner: IXMLNode);
begin
  inherited Create;

  FOwner := Owner;
end;

destructor IXMLNodeList.Destroy;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
  begin
    Items[i].Free;
    Delete(i);
  end;

  inherited;
end;

function IXMLNodeList.FindNode(Name: String): IXMLNode;
var
  i: Integer;
begin
  Result := nil;
  Name := AnsiLowerCase(Name);

  for i := 0 to Count - 1 do
    if AnsiLowerCase(Items[i].FName) = Name then
    begin
      Result := Items[i];
      Break;
    end;
end;

function IXMLNodeList.Get(Index: Integer): IXMLNode;
begin
  Result := IXMLNode(inherited Get(Index));
end;

procedure IXMLNodeList.Put(Index: Integer; Node: IXMLNode);
begin
  inherited Put(Index, Node);
end;

function IXMLNodeList.Remove(Item: IXMLNode): Integer;
begin
  Result := inherited Remove(Item);
  Item.FParent := nil;
end;

function IXMLNodeList.RemoveAndFree(Item: IXMLNode): Integer;
begin
  Result := inherited Remove(Item);
  Item.Free;
end;

end.
