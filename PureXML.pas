unit PureXML;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes;

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
  public
    Value: Variant;
    NodeType: TNodeType;

    constructor Create(aParent: IXMLNode; aNodeType: TNodeType);
    destructor Destroy; override;

    function ChildNodes: IXMLNodeList; overload;
    function ChildNodes(Index: Integer): IXMLNode; overload;
    function ChildNodes(Name: String): IXMLNode; overload;
    function ChildValues(Name: String): Variant;
    function Attributes(Name: String): String;
  end;

  IXMLNodeList = class(TList)
  protected
    function Get(Index: Integer): IXMLNode;
    procedure Put(Index: Integer; Node: IXMLNode);
  public
    destructor Destroy; override;
    function FindNode(Name: String): IXMLNode;
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
      value := #0;

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
    Value := StringReplace(Value, #0, '', [rfReplaceAll]);
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
    if VarToStr(Nodes[i].Value) <> '' then
      FslXML.Add(ParentTab + FTab + '<' + Nodes[i].FName + AttributesToString(Nodes[i]) + '>' + VarToStr(Nodes[i].Value) + '</' + Nodes[i].FName + '>')
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

  FXML.FName := Match; // should be XML header
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
        ParentNode.Value := Copy(sXML, ParentNode.FDataStart, iStart - ParentNode.FDataStart);
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

constructor IXMLNode.Create(aParent: IXMLNode; aNodeType: TNodeType);
begin
  inherited Create;

  FParent := aParent;
  FNodes := IXMLNodeList.Create;
  FAttributes := TStringList.Create;

  NodeType := aNodeType;
end;

destructor IXMLNode.Destroy;
begin
  FNodes.Free;
  FAttributes.Free;

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

function IXMLNode.Attributes(Name: String): String;
begin
  Result := FAttributes.Values[Name];
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
  Result := Node.Value;
end;


{ IXMLNodeList }

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

end.
